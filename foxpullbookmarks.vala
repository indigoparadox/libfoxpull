
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

   private void bookmark_callback(
      Json.Array array,
      uint index,
      Json.Node element_node
   ) {
      string bm_id = element_node.get_string();
      string bm_path = "storage/bookmarks/%s".printf( bm_id );
      string bm_json;
      GenericArray<string> bm_tags = new GenericArray<string>();
      GenericArray<string> bm_children = new GenericArray<string>();
      Json.Parser parser;
      Json.Object root_object;
      
      try {
         bm_json = this.encryptor.request_plain( bm_path );

         parser = new Json.Parser();
         parser.load_from_data( bm_json );
         root_object = parser.get_root().get_object();

         //stdout.printf( "%s\n", bm_json );

         // TODO
         if( root_object.has_member( "children" ) ) {
            root_object.get_array_member( "children" ).foreach_element(
               ( array, index, element_node ) => {
                  bm_children.add( element_node.get_string() );
               }
            );
         }

         if( root_object.has_member( "tags" ) ) {
            root_object.get_array_member( "tags" ).foreach_element(
               ( array, index, element_node ) => {
                  bm_tags.add( element_node.get_string() );
               }
            );
         }

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
               (string[])bm_children.data,
               root_object.has_member( "parentid" ) &&
                  null != root_object.get_string_member( "parentid" ) ?
                  root_object.get_string_member( "parentid" ) : "",
               root_object.has_member( "bmkUri" ) &&
                  null != root_object.get_string_member( "bmkUri" ) ?
                  root_object.get_string_member( "bmkUri" ) : "",
               (string[])bm_tags.data,
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
         warning( e.message );
         return;
      }

      //count++;
      this.bookmarks_processed++;
   }

   public int foreach_bookmark(
      BookmarkDelegate delegator,
      string? last_sync
   ) {
      Json.Parser parser;
      Json.Array root_array;
      string bookmarks;
      string request_path;

      // Limit request to bookmarks newer than the given timestamp.
      if( null == last_sync ) {
         request_path = "storage/bookmarks";
      } else {
         request_path = "storage/bookmarks?newer=%s".printf( last_sync );
      }

      // Grab the list of bookmarks.
      try {
         bookmarks = this.encryptor.request_plain( request_path );
         parser = new Json.Parser();
         parser.load_from_data( bookmarks );
         root_array = parser.get_root().get_array();
      } catch( GLib.Error e ) {
         warning( e.message );
         return -1;
      }

      // Iterate, pull, and process each bookmark in detail.
      this.bookmarks_processed = 0;
      this.list_delegator = ( // https://stackoverflow.com/questions/16693847/how-to-get-rid-of-the-vala-compilation-warning-copying-delegates-is-discouraged
         id, type, parent_name, title, description, children, parent_id,
         bmk_uri, tags, keyword, load_in_sidebar, deleted
      ) => { delegator(
         id, type, parent_name, title, description, children, parent_id,
         bmk_uri, tags, keyword, load_in_sidebar, deleted
      ); };
      root_array.foreach_element(
         this.bookmark_callback
      );

      return this.bookmarks_processed;
   }

   public FoxPullBookmarks( FoxPullEncryptor encryptor ) {
      this.encryptor = encryptor;
   }
}

