
#include <stdint.h>
#include <openssl/conf.h>
#include <openssl/evp.h>
#include <openssl/err.h>

char* libfoxpull_decrypt(
   uint8_t ciphertext[], int ciphertext_len, uint8_t iv[], uint8_t key[]
) {
   int inter_plaintext_len = 0;
   int real_plaintext_len = 0;
   EVP_CIPHER_CTX* ctx = NULL;
   char* plaintext_out = NULL;

   printf( "%s\n", ciphertext );
   
   plaintext_out = calloc( ciphertext_len * 2, sizeof( char ) );

   ERR_load_crypto_strings();
   OpenSSL_add_all_algorithms();
   OPENSSL_config( NULL );

   if( !(ctx = EVP_CIPHER_CTX_new()) ) {
      free( plaintext_out );
      plaintext_out = NULL;
      goto cleanup;
   }

   if( 1 != EVP_DecryptInit_ex( ctx, EVP_aes_256_cbc(), NULL, key, iv ) ) {
      free( plaintext_out );
      plaintext_out = NULL;
      goto cleanup;
   }

   if( 1 != EVP_DecryptUpdate(
      ctx, plaintext_out, &inter_plaintext_len, ciphertext, ciphertext_len
   ) ) {
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

   /*
   if( 1 != EVP_DecryptFinal_ex(
      ctx, plaintext_out + real_plaintext_len, &inter_plaintext_len
   ) ) {
      printf( "foo\n" );
      free( plaintext_out );
      plaintext_out = NULL;
      goto cleanup;
   }
   real_plaintext_len += inter_plaintext_len;
   */

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
