
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

#include <glib.h>
#include <openssl/conf.h>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/hmac.h>

gchar* libfoxpull_hash_hmac( 
   guint8* key, gint key_len, guint8* data, gint data_len, guint* hash_len
) {
   guint8* hash_out = NULL;

   hash_out = g_new( gchar, EVP_MAX_MD_SIZE );
   *hash_len = EVP_MAX_MD_SIZE;

   HMAC(
      EVP_sha256(), key, key_len, data, data_len, hash_out, hash_len
   );

cleanup:
   
   return hash_out;
}

gchar* libfoxpull_decrypt(
   guint8* ciphertext, gint ciphertext_len, guint8* iv, guint8* key
) {
   int inter_plaintext_len = 0;
   int real_plaintext_len = 0;
   EVP_CIPHER_CTX* ctx = NULL;
   gchar* plaintext_out = NULL;

   plaintext_out = g_new( gchar, ciphertext_len );

   ERR_load_crypto_strings();
   OpenSSL_add_all_algorithms();
   OPENSSL_config( NULL );

   if( !(ctx = EVP_CIPHER_CTX_new()) ) {
      BIO_dump_fp( stderr, ciphertext, ciphertext_len );
      ERR_print_errors_fp( stderr );
      g_clear_pointer( &plaintext_out, g_free );
      goto cleanup;
   }

   EVP_CIPHER_CTX_set_padding( ctx, 0 );

   if( !EVP_DecryptInit_ex( ctx, EVP_aes_256_cbc(), NULL, key, iv ) ) {
      BIO_dump_fp( stderr, ciphertext, ciphertext_len );
      ERR_print_errors_fp( stderr );
      g_clear_pointer( &plaintext_out, g_free );
      goto cleanup;
   }

   if( !EVP_DecryptUpdate(
      ctx, plaintext_out, &inter_plaintext_len, ciphertext, ciphertext_len
   ) ) {
      BIO_dump_fp( stderr, ciphertext, ciphertext_len );
      ERR_print_errors_fp( stderr );
      g_clear_pointer( &plaintext_out, g_free );
      goto cleanup;
   }
   real_plaintext_len = inter_plaintext_len;

   #if 0
   if( real_plaintext_len > plaintext_out_len ) {
      /* This shouldn't happen. */
      free( plaintext_out );
      plaintext_out = NULL;
      goto cleanup;
   }
   #endif

   if( !EVP_DecryptFinal_ex(
      ctx, plaintext_out + real_plaintext_len, &inter_plaintext_len
   ) ) {
      BIO_dump_fp( stderr, ciphertext, ciphertext_len );
      ERR_print_errors_fp( stderr );
      g_clear_pointer( &plaintext_out, g_free );
      goto cleanup;
   }
   real_plaintext_len += inter_plaintext_len;

   #if 0
   if( real_plaintext_len > plaintext_out_len ) {
      /* This shouldn't happen. */
      free( plaintext_out );
      plaintext_out = NULL;
      goto cleanup;
   }
   #endif

   plaintext_out[real_plaintext_len] = '\0';

cleanup:

   if( NULL != ctx ) {
      EVP_CIPHER_CTX_free( ctx );
   }

   EVP_cleanup();
   ERR_free_strings();
   
   return plaintext_out;
}

