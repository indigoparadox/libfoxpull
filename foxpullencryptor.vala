
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

public class FoxPullEncryptor : GLib.Object {

   private string server;
   private string userhash;
   private string password;
   private string localkey;
   private string syncapi = "1.0";

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

      stdout.printf( "%s\n", url );

      // Perform the actual request.
      session = new Soup.Session();
      session.authenticate.connect( this.on_auth );
      message = new Soup.Message( "GET", url );
      session.send_message( message );

      // TODO: Check for errors.
      data = (string)message.response_body.flatten().data;

      // FF Sync seems to return some wonky JSON with quoted objects.
      data = data
         .replace( "\"{", "{" )
         .replace( "}\"", "}" )
         .replace( "\\\"", "\"" );

      return data;
   }

   private string digest_key( string key ) {
      string normalized_key;
      unowned uint8[] normalized_key_encoded;
      string formatted_hash;
      int padding;

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
      normalized_key_encoded = Base32.encode( normalized_key.data );

      // '{}{}\x01'.format( 'Sync-AES_256_CBC-HMAC256', self.userhash ),
      formatted_hash = "Sync-AES_256_CBC-HMAC256%s\x01".printf(
         this.userhash
      );

      return GLib.Hmac.compute_for_string(
         GLib.ChecksumType.SHA256,
         normalized_key_encoded,
         formatted_hash
      );
   }

   private string decrypt( string ciphertext, string hmac, string iv ) {
      // TODO
      return ciphertext;
   }

   public string request_plain( string path ) {
      string data_ciphertext;
      string data_hmac;
      string data_iv;
      string data_json;
      Json.Parser parser;
      Json.Object root_object;

      data_json = this.request_encrypted( path );
      parser = new Json.Parser();
      parser.load_from_data( data_json );
      root_object = parser.get_root().get_object();
      //payload = json.loads( data['payload'] )

      // Grab the parts of the encrypted payload.
      data_ciphertext = root_object.get_object_member( "payload" )
                                   .get_string_member( "ciphertext" );

      data_hmac = root_object.get_object_member( "payload" )
                             .get_string_member( "hmac" );

      data_iv = root_object.get_object_member( "payload" )
                           .get_string_member( "IV" );

      return this.decrypt( data_ciphertext, data_hmac, data_iv );
   }

   public FoxPullEncryptor(
      string server,
      string username,
      string password,
      string key
   ) {
      string default_key;

      // Setup member fields.
      this.server = server;
      this.userhash = this.encode_username( username );
      this.password = password;
      // self.node = self._request_node().rstrip( '/' )
      this.localkey = this.digest_key( key );

      try {
         default_key = this.request_plain( "storage/crypto/keys" );
      } catch( Error e ) {
         // TODO
      }

      //stdout.printf( "%s\n", default_key );

      //this.privkey = default_key[0].decode( 'base64' );
      //this.privhmac = default_key[1].decode( 'base64' );
   }
}
