
public class FoxPullBookmarks : GLib.Object {

   public delegate void BookmarkDelegate(
      string bookmark_id
   );

   private FoxPullEncryptor encryptor;

   private int bookmarks_processed;
   private BookmarkDelegate list_delegator;

   private void bookmark_callback(
      Json.Array array,
      uint index,
      Json.Node element_node
   ) {
      string bm_id = element_node.get_string();
      string bm_path = "storage/bookmarks/%s".printf( bm_id );
      string bm_json;
      Json.Parser parser;
      
      try {
         bm_json = this.encryptor.request_plain( bm_path );

         this.list_delegator( bm_json );
      } catch( GLib.Error e ) {
         // TODO
         return;
      }

      //count++;
      this.bookmarks_processed++;
   }

   public int foreach_bookmark( BookmarkDelegate delegator ) {
      Json.Parser parser;
      Json.Array root_array;
      string bookmarks;

      try {
         bookmarks = this.encryptor.request_plain( "storage/bookmarks" );
         parser = new Json.Parser();
         parser.load_from_data( bookmarks );
         root_array = parser.get_root().get_array();
      } catch( GLib.Error e ) {
         // TODO
         return -1;
      }

      this.bookmarks_processed = 0;
      this.list_delegator = delegator;

      root_array.foreach_element(
         this.bookmark_callback
      );

      return this.bookmarks_processed;
   }

   public FoxPullBookmarks( FoxPullEncryptor encryptor ) {
      this.encryptor = encryptor;
   }
}

