
/* This file is part of libfoxpull.
 * 
 * libfoxpull is free software: you can redistribute it and/or modify it under 
 * the terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 * 
 * libfoxpull is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License
 * for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with libfoxpull.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Soup;
using Json;

/* Functions from SSL bridge. */
extern string libfoxpull_decrypt( 
   uint8* ciphertext, int ciphertext_len,
   uint8* iv, uint8* key
);
extern uint8[] libfoxpull_hash_hmac( 
   uint8* key, int key_len, uint8* data, int data_len, ref uint hash_len
);

public class FoxPullEncryptor : GLib.Object {

   private string server;
   private string userhash;
   private string password;
   private string syncapi = "1.0";
   private uint8[] privkey;

   private void on_auth( Message msg, Auth auth, bool retry ) {
      auth.authenticate( this.userhash, this.password );
   }

   private string encode_username( string username ) {
      unowned uint8[] username_hash_encoded;
      GLib.Checksum username_checksum;
      uint8 checksum_bytes[255] = { 0 }; // Hopefully sufficient for now.
      size_t checksum_len = 255;

      // The get_digest() method really needs work.
      username_checksum = new GLib.Checksum( GLib.ChecksumType.SHA1 );
      username_checksum.update( username.data, username.length );
      username_checksum.get_digest( checksum_bytes, ref checksum_len );

      // It took a lot of experimentation to find a way vala would accept to
      // chop the rest of the buffer off.
      var checksum_bytes_trim = new uint8[checksum_len];
      for( int i = 0 ; i < checksum_len ; i++ ) {
         checksum_bytes_trim[i] = checksum_bytes[i];
      }

      // Encode the binary checksum and return it.
      username_hash_encoded = Base32.encode( checksum_bytes_trim );
      return ((string)username_hash_encoded).down();
   }

   private string request_encrypted( string path ) {
      Soup.Session session;
      Soup.Message message;
      string url;
      string data;

      // Build the URL to the path on our sync server.
      url = "%s/%s/%s/%s".printf(
         this.server, this.syncapi, this.userhash, path
      );

      // Perform the actual request.
      session = new Soup.Session();
      session.authenticate.connect( this.on_auth );
      message = new Soup.Message( "GET", url );
      session.send_message( message );

      // TODO: Check for errors.
      data = (string)message.response_body.flatten().data;

      // FF Sync seems to return some wonky JSON with quoted objects.
      // TODO: Actually, payload might just be another JSON string.
      data = data
         .replace( "\"{", "{" )
         .replace( "}\"", "}" )
         .replace( "\\\"", "\"" );

      return data;
   }

   private uint8[] digest_key( string key ) {
      string normalized_key;
      unowned uint8[] normalized_key_decoded;
      int normalized_key_decoded_len = 0;
      string formatted_hash;
      int padding;
      uint8[] hash;
      uint hash_len = 0;

      // Strip out/replace invalid characters.
      normalized_key = key
         .replace( "-", "" )
         .replace( "8", "l" )
         .replace( "9", "o" )
         .up();

      // Add padding to the key.
      padding = (8 - normalized_key.length % 8) % 8;
      for( int i = 0; padding > i ; i++ ) {
         normalized_key.concat( "=" );
      }
      normalized_key_decoded = Base32.decode(
         normalized_key.data, ref normalized_key_decoded_len
      );

      // '{}{}\x01'.format( 'Sync-AES_256_CBC-HMAC256', self.userhash ),
      formatted_hash = "Sync-AES_256_CBC-HMAC256%s%c".printf(
         this.userhash, 0x01
      );

      hash = libfoxpull_hash_hmac( 
         normalized_key_decoded, normalized_key_decoded_len,
         formatted_hash.data, formatted_hash.length,
         ref hash_len
      );

      return hash;
   }

   private string request_plain_with_key(
      string path, uint8[] key
   ) throws GLib.Error {
      string data_ciphertext;
      string data_iv;
      string data_json;
      uint8[] data_ciphertext_decoded;
      uint8[] data_iv_decoded;
      string data_plaintext;
      Json.Parser parser;
      Json.Object root_object;
      Json.Object payload_object;

      data_json = this.request_encrypted( path );
      parser = new Json.Parser();
      parser.load_from_data( data_json );
      root_object = parser.get_root().get_object();

      // TODO: Handle missing payload.

      // Grab the parts of the encrypted payload.
      payload_object = root_object.get_object_member( "payload" );
      if( null != payload_object ) {
         data_ciphertext = payload_object.get_string_member( "ciphertext" );
         data_ciphertext_decoded = GLib.Base64.decode( data_ciphertext );
         data_iv = payload_object.get_string_member( "IV" );
         data_iv_decoded = GLib.Base64.decode( data_iv );

         if( null == (data_plaintext = libfoxpull_decrypt( 
            data_ciphertext_decoded,
            data_ciphertext_decoded.length,
            data_iv_decoded,
            key
         )) ) {
            // TODO
         }
      } else {
         data_plaintext = data_json;
      }

      return data_plaintext;
   }

   private uint8[] request_key(
      string path, uint8[] key
   ) throws GLib.Error {
      string key_json;
      string key_encoded;
      Json.Parser parser;
      Json.Object root_object;

      key_json = this.request_plain_with_key( path, key );
      parser = new Json.Parser();
      parser.load_from_data( key_json );
      root_object = parser.get_root().get_object();

      key_encoded = root_object.get_array_member( "default" )
                               .get_string_element( 0 );

      return GLib.Base64.decode( key_encoded );
   }

   public string request_plain( string path ) throws GLib.Error {
      return this.request_plain_with_key( path, this.privkey );
   }

   public FoxPullEncryptor(
      string server,
      string username,
      string password,
      string key
   ) {
      uint8[] local_key;

      // Setup member fields.
      this.server = server;
      this.userhash = this.encode_username( username );
      this.password = password;
      local_key = this.digest_key( key );

      try {
         this.privkey = this.request_key(
            "storage/crypto/keys",
            local_key
         );
      } catch( Error e ) {
         // TODO
      }
   }
}

