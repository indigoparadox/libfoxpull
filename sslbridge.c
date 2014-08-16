
#include <glib.h>
#include <openssl/conf.h>
#include <openssl/evp.h>
#include <openssl/err.h>

gchar* libfoxpull_decrypt(
   guint8* ciphertext, gint ciphertext_len, guint8* iv, guint8* key
) {
   int inter_plaintext_len = 0;
   int real_plaintext_len = 0;
   EVP_CIPHER_CTX* ctx = NULL;
   char* plaintext_out = NULL;

   plaintext_out = calloc( ciphertext_len * 2, sizeof( char ) );

   ERR_load_crypto_strings();
   OpenSSL_add_all_algorithms();
   OPENSSL_config( NULL );

   if( !(ctx = EVP_CIPHER_CTX_new()) ) {
      BIO_dump_fp( stderr, ciphertext, ciphertext_len );
      ERR_print_errors_fp( stderr );
      free( plaintext_out );
      plaintext_out = NULL;
      goto cleanup;
   }

   EVP_CIPHER_CTX_set_padding( ctx, 0 );

   if( !EVP_DecryptInit_ex( ctx, EVP_aes_256_cbc(), NULL, key, iv ) ) {
      BIO_dump_fp( stderr, ciphertext, ciphertext_len );
      ERR_print_errors_fp( stderr );
      free( plaintext_out );
      plaintext_out = NULL;
      goto cleanup;
   }

   if( !EVP_DecryptUpdate(
      ctx, plaintext_out, &inter_plaintext_len, ciphertext, ciphertext_len
   ) ) {
      BIO_dump_fp( stderr, ciphertext, ciphertext_len );
      ERR_print_errors_fp( stderr );
      free( plaintext_out );
      plaintext_out = NULL;
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
      free( plaintext_out );
      plaintext_out = NULL;
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

