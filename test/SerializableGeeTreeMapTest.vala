using GXml;
using Gee;

class SerializableGeeTreeMapTest : GXmlTest
{
  class Space : SerializableObjectModel, SerializableMapKey<string>
  {
    public string get_map_key () { return name; }
    public string name { get; set; }
    public Space.named (string name) { this.name = name; }
    public override string node_name () { return "space"; }
    public override string to_string () { return name; }
  }

  class SpaceContainer : SerializableObjectModel
  {
    public string owner { get; set; }
    public SpaceCollection storage { get; set; }
    public override string node_name () { return "spacecontainer"; }
    public override string to_string () { return owner; }
    public override GXml.Node? deserialize (GXml.Node node)
                                    throws GLib.Error
    {
      Element element;
      if (node is Document)
        element = ((Document) node).document_element;
      else
        element = (Element) node;
      if (element.has_child_nodes ()) {
        if (storage == null)
          storage = new SpaceCollection ();
        storage.deserialize (element);
      }
      return default_deserialize (node);
    }
    public class SpaceCollection : SerializableTreeMap<string,Space> {}
  }

  public static void add_tests ()
  {
    Test.add_func ("/gxml/serializable/serializable_tree_map/api",
    () => {
      try {
        var c = new SerializableTreeMap<string,Space> ();
        var o1 = new Space.named ("Big");
        var o2 = new Space.named ("Small");
        c.set (o1.name, o1);
        c.set (o2.name, o2);
        bool found1 = false;
        bool found2 = false;
        foreach (Space o in c.values) {
          if (o.name == "Big") found1 = true;
          if (o.name == "Small") found2 = true;
        }
        if (!found1) {
          stdout.printf (@"Big is not found\n");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"Small is not found\n");
          assert_not_reached ();
        }
        found1 = found2 = false;
        foreach (string k in c.keys) {
          if ((c.@get (k)).name == "Big") found1 = true;
          if ((c.@get (k)).name == "Small") found2 = true;
        }
        if (!found1) {
          stdout.printf (@"Big key value is not found\n");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"Small key value is not found\n");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
      }
    });
    Test.add_func ("/gxml/serializable/serializable_tree_map/serialize",
    () => {
      try {
        var c = new SerializableTreeMap<string,Space> ();
        var o1 = new Space.named ("Big");
        var o2 = new Space.named ("Small");
        c.set (o1.name, o1);
        c.set (o2.name, o2);
        var doc = new Document ();
        var root = doc.create_element ("root");
        doc.append_child (root);
        c.serialize (root);
        if (!root.has_child_nodes ()) {
          stdout.printf (@"ERROR: root node have no childs $(doc)\n");
          assert_not_reached ();
        }
        bool found1 = false;
        bool found2 = false;
        foreach (GXml.Node n in root.child_nodes) {
          if (n is Element && n.node_name == "space") {
            var name = ((Element) n).get_attribute_node ("name");
            if (name != null) {
              if (name.node_value == "Big") found1 = true;
              if (name.node_value == "Small") found2 = true;
            }
          }
        }
        if (!found1) {
          stdout.printf (@"ERROR: Big space node is not found\n$(doc)\n");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"ERROR: Small space node is not found\n$(doc)\n");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/serializable/serializable_tree_map/deserialize",
    () => {
      try {
        var doc = new Document.from_string ("""<?xml version="1.0"?>
  <root><space name="Big"/><space name="Small"/></root>""");
        var c = new SerializableTreeMap<string,Space> ();
        c.deserialize (doc.document_element);
        if (c.size != 2) {
          stdout.printf (@"ERROR: incorrect size must be 2 got: $(c.size)\n");
          assert_not_reached ();
        }
        bool found1 = false;
        bool found2 = false;
        foreach (string k in c.keys) {
          if ((c.@get (k)).name == "Big") found1 = true;
          if ((c.@get (k)).name == "Small") found2 = true;
        }
        if (!found1) {
          stdout.printf (@"ERROR: Big key value is not found\n");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"ERROR: Small key value is not found\n");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/serializable/serializable_tree_map/container_class/deserialize",
    () => {
      try {
        var doc = new Document.from_string ("""<?xml version="1.0"?>
  <spacecontainer owner="Earth"><space name="Big"/><space name="Small"/></spacecontainer>""");
        var c = new SpaceContainer ();
        c.deserialize (doc);
        if (c.owner != "Earth") {
          stdout.printf (@"ERROR: owner must be 'Earth' got: $(c.owner)\n$(doc)\n");
          assert_not_reached ();
        }
        if (c.storage.size != 2) {
          stdout.printf (@"ERROR: Size must be 2 got: $(c.storage.size)\n$(doc)\n");
          assert_not_reached ();
        }
        bool found1 = false;
        bool found2 = false;
        foreach (string k in c.storage.keys) {
          if ((c.storage.@get (k)).name == "Big") found1 = true;
          if ((c.storage.@get (k)).name == "Small") found2 = true;
        }
        if (!found1) {
          stdout.printf (@"ERROR: Big key value is not found\n");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"ERROR: Small key value is not found\n");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
        assert_not_reached ();
      }
    });
    Test.add_func ("/gxml/serializable/serializable_tree_map/containder_class/serialize",
    () => {
      try {
        var c = new SpaceContainer ();
        var o1 = new Space.named ("Big");
        var o2 = new Space.named ("Small");
        c.storage = new SpaceContainer.SpaceCollection ();
        c.storage.set (o1.name, o1);
        c.storage.set (o2.name, o2);
        var doc = new Document ();
        c.serialize (doc);
        if (doc.document_element == null) {
          stdout.printf (@"ERROR: doc have no root node\n$(doc)\n");
          assert_not_reached ();
        }
        if (doc.document_element.node_name != "spacecontainer") {
          stdout.printf (@"ERROR: bad doc root node's name: $(doc.document_element.node_name)\n$(doc)\n");
          assert_not_reached ();
        }
        var root = doc.document_element;
        if (!root.has_child_nodes ()) {
          stdout.printf (@"ERROR: root node have no childs $(doc)\n");
          assert_not_reached ();
        }
        bool found1 = false;
        bool found2 = false;
        foreach (GXml.Node n in root.child_nodes) {
          if (n is Element && n.node_name == "space") {
            var name = ((Element) n).get_attribute_node ("name");
            if (name != null) {
              if (name.node_value == "Big") found1 = true;
              if (name.node_value == "Small") found2 = true;
            }
          }
        }
        if (!found1) {
          stdout.printf (@"ERROR: Big space node is not found\n$(doc)\n");
          assert_not_reached ();
        }
        if (!found2) {
          stdout.printf (@"ERROR: Small space node is not found\n$(doc)\n");
          assert_not_reached ();
        }
      }
      catch (GLib.Error e) {
        stdout.printf (@"ERROR: $(e.message)");
        assert_not_reached ();
      }
    });
  }
}