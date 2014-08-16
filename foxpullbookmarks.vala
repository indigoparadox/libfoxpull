
public class FoxPullBookmarks : GLib.Object {

   public delegate void BookmarkDelegate(
      string id,
      string type,
      string parent_name,
      string title,
      string description,
      string[] children,
      string parent_id,
      string bmk_uri,
      string[] tags,
      string keyword,
      bool load_in_sidebar,
      bool deleted
   );

   private FoxPullEncryptor encryptor;

   private int bookmarks_processed;
   private BookmarkDelegate list_delegator;
   private string[] building_string;

   private void bookmark_callback(
      Json.Array array,
      uint index,
      Json.Node element_node
   ) {
      string bm_id = element_node.get_string();
      string bm_path = "storage/bookmarks/%s".printf( bm_id );
      string bm_json;
      string[] bm_tags = {};
      string[] bm_children = {};
      Json.Parser parser;
      Json.Object root_object;
      
      try {
         bm_json = this.encryptor.request_plain( bm_path );

         parser = new Json.Parser();
         parser.load_from_data( bm_json );
         root_object = parser.get_root().get_object();

         //stdout.printf( "%s\n", bm_json );

         // TODO
         /*root_object.get_array_member( "children" ).foreach_element(
            ( array, index, element_node ) => {
               //this.building_string.append( element_node.get_string() );
            }
         );*/

         //root_object.get_array_member( "tags" ),

         if( null != root_object ) {
            this.list_delegator(
               bm_id,
               root_object.get_string_member( "type" ),
               root_object.has_member( "parentName" ) &&
                  null != root_object.get_string_member( "parentName" ) ?
                  root_object.get_string_member( "parentName" ) : "",
               root_object.has_member( "title" ) &&
                  null != root_object.get_string_member( "title" ) ?
                  root_object.get_string_member( "title" ) : "",
               root_object.has_member( "description" ) &&
                  null != root_object.get_string_member( "description" ) ?
                  root_object.get_string_member( "description" ) : "",
               bm_children,
               root_object.has_member( "parentid" ) &&
                  null != root_object.get_string_member( "parentid" ) ?
                  root_object.get_string_member( "parentid" ) : "",
               root_object.has_member( "bmkUri" ) &&
                  null != root_object.get_string_member( "bmkUri" ) ?
                  root_object.get_string_member( "bmkUri" ) : "",
               bm_tags,
               root_object.has_member( "keyword" ) &&
                  null != root_object.get_string_member( "keyword" ) ?
                  root_object.get_string_member( "keyword" ) : "",
               root_object.has_member( "loadInSidebar" ) ?
                  root_object.get_boolean_member( "loadInSidebar" ) : false,
               root_object.has_member( "deleted" ) ?
                  root_object.get_boolean_member( "deleted" ) : false
            );
         }
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

