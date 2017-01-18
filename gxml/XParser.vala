/* TNode.vala
 *
 * Copyright (C) 2016  Daniel Espinosa <esodan@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *      Daniel Espinosa <esodan@gmail.com>
 */

using Gee;
using Xml;

/**
 * {@link Parser} implementation using libxml2 engine
 */
public class GXml.XParser : Object, GXml.Parser {
  private DomDocument _document;
  private DomNode _node;
  private TextReader tr;
  private Xml.TextWriter tw;

  public bool backup { get; set; }
  public bool indent { get; set; }

  public DomNode node { get { return _node; } }


  public XParser (DomNode node) {
    _node = node;
    if (_node is DomDocument)
      _document = _node as DomDocument;
    else
      _document = _node.owner_document;
  }

  construct {
    backup = true;
    indent = false;
  }

  public void write_stream (OutputStream stream,
                            GLib.Cancellable? cancellable) throws GLib.Error {
    var buf = new Xml.Buffer ();
    tw = Xmlx.new_text_writer_memory (buf, 0);
    if (_node is DomDocument) tw.start_document ();
    tw.set_indent (indent);
    // Root
    if (_node is DomDocument) {
      if ((_node as DomDocument).document_element == null)
        tw.end_document ();
    }
#if DEBUG
    GLib.message ("Starting writting Document child nodes");
#endif
    start_node (_node);
#if DEBUG
    GLib.message ("Ending writting Document child nodes");
#endif
    tw.end_element ();
#if DEBUG
    GLib.message ("Ending Document");
#endif
    tw.end_document ();
    tw.flush ();
    var s = new GLib.StringBuilder ();
    s.append (buf.content ());
    var b = new GLib.MemoryInputStream.from_data (s.data, null);
    stream.splice (b, GLib.OutputStreamSpliceFlags.NONE);
    stream.close ();
  }

  public string write_string () throws GLib.Error  {
    return dump ();
  }
  public void read_string (string str, GLib.Cancellable? cancellable) throws GLib.Error {
    if (str == "")
      throw new ParserError.INVALID_DATA_ERROR (_("Invalid document string, it is empty or is not allowed"));
    StringBuilder s = new StringBuilder (str);
    var stream = new GLib.MemoryInputStream.from_data (str.data);
    read_stream (stream, cancellable);
  }


  public void read_stream (GLib.InputStream istream,
                          GLib.Cancellable? cancellable) throws GLib.Error {
    var b = new MemoryOutputStream.resizable ();
    b.splice (istream, 0);
#if DEBUG
    GLib.message ("DATA:"+(string)b.data);
#endif
    tr = new TextReader.for_memory ((char[]) b.data, (int) b.get_data_size (), "/gxml_memory");
    read_node (_node);
  }
  /**
   * Reads a node using current parser.
   */
  public void read_node (DomNode node) throws GLib.Error {
    move_next_node ();
    if (node is DomElement) {
      while (true) {
#if DEBUG
        GLib.message ("Node's name: "+(node as DomElement).local_name.down ());
        GLib.message ("Current Node's name: "+current_node_name ().down ());
        GLib.message ("Current Node is Element: "+current_is_element ().to_string ());
#endif
        break;
        if (current_is_element ()
            &&
            (current_node_name ().down () == (node as DomElement).local_name.down ())) {
          break;
        }
        if (!current_is_document ()) {
          read_child_node (_document);
        }
        if (!move_next_node ()) break;
      }
#if DEBUG
        GLib.message ("Found Element node: "+current_node_name ());
#endif
      read_element (node as DomElement);
    }
#if DEBUG
        GLib.message ("Parsing child nodes of: "+node.node_name);
#endif
    read_child_nodes (node);
  }
  /**
   * Use parser to go to next parsed node.
   */
  public bool move_next_node () throws GLib.Error {
    int res = tr.read ();
    if (res == -1)
      throw new ParserError.INVALID_DATA_ERROR (_("Can't read node data"));
    if (res == 0) {
#if DEBUG
      GLib.message ("ReadNode: No more nodes");
#endif
      return false;
    }
    return true;
  }
  /**
   * Check if current node has childs.
   */
  public bool current_has_childs () {
    return tr.is_empty_element () != 1;
  }
  /**
   * Check if current node found by parser, is a {@link DomElement}
   */
  public bool current_is_element () {
    return (tr.node_type () == Xml.ReaderType.ELEMENT);
  }
  /**
   * Check if current node found by parser, is a {@link DomDocument}
   */
  public bool current_is_document() {
    return (tr.node_type () == Xml.ReaderType.DOCUMENT);
  }
  /**
   * Returns current node's local name, found by parser.
   */
  public string current_node_name () {
    return tr.const_local_name ();
  }
  /**
   * Creates a new {@link DomElement} and append it as a child of parent.
   */
  public DomElement? create_element (DomNode parent) {
    DomElement n = null;
#if DEBUG
    GLib.message ("Creating a standard element: "
                  +tr.const_local_name ());
    GLib.message ("Reading: Element: "+tr.const_local_name ());
#endif
    string prefix = tr.prefix ();
    if (prefix != null) {
#if DEBUG
      GLib.message ("Is namespaced element");
#endif
      string nsuri = tr.lookup_namespace (prefix);
      n = _document.create_element_ns (nsuri, tr.prefix () +":"+ tr.const_local_name ());
    } else
      n = _document.create_element (tr.const_local_name ());
    parent.append_child (n);
    return n;
  }
  /**
   * Reads a {@link DomElement}
   */
  public void read_element (DomElement element) throws GLib.Error {
    var nattr = tr.attribute_count ();
#if DEBUG
    GLib.message ("Current reading Element:"+element.local_name);
    GLib.message ("Number of Attributes:"+nattr.to_string ());
#endif
    for (int i = 0; i < nattr; i++) {
      var c = tr.move_to_attribute_no (i);
#if DEBUG
      GLib.message ("Current Attribute: "+i.to_string ());
#endif
      if (c != 1) {
        throw new DomError.HIERARCHY_REQUEST_ERROR (_("Parsing ERROR: Fail to move to attribute number: %i").printf (i));
      }
      if (tr.is_namespace_decl () == 1) {
#if DEBUG
        GLib.message ("Is Namespace Declaration...");
#endif
        string nsp = tr.const_local_name ();
        string aprefix = tr.prefix ();
        tr.read_attribute_value ();
        if (tr.node_type () == Xml.ReaderType.TEXT) {
          string ansuri = tr.read_string ();
#if DEBUG
          GLib.message ("Property Read: "+aprefix+":"+nsp+"="+ansuri);
#endif
          string ansp = nsp;
          if (nsp != "xmlns")
            ansp = aprefix+":"+nsp;
#if DEBUG
          GLib.message ("To append: "+ansp+"="+ansuri);
#endif
          element.set_attribute_ns ("http://www.w3.org/2000/xmlns/",
                                               ansp, ansuri);
        }
      } else {
        var attrname = tr.const_local_name ();
        string prefix = tr.prefix ();
#if DEBUG
        GLib.message ("Attribute: "+tr.const_local_name ());
#endif
        tr.read_attribute_value ();
        if (tr.node_type () == Xml.ReaderType.TEXT) {
          var attrval = tr.read_string ();
#if DEBUG
          GLib.message ("Attribute:"+attrname+" Value: "+attrval);
#endif
          bool processed = false;
          if (node is GomObject) {
            processed = (element as GomObject).set_attribute (attrname, attrval);
          }
          if (!processed) {
            if (prefix != null) {
#if DEBUG
              GLib.message ("Prefix found: "+prefix);
#endif
              string nsuri = null;
              if (prefix == "xml")
                nsuri = "http://www.w3.org/2000/xmlns/";
              else
                nsuri = tr.lookup_namespace (prefix);
              element.set_attribute_ns (nsuri, prefix+":"+attrname, attrval);
            } else
              element.set_attribute (attrname, attrval);
          }
        }
      }
    }
  }
  /**
   * Iterates in all child nodes and append them to node.
   */
  public void read_child_nodes (DomNode parent) throws GLib.Error {
#if DEBUG
      GLib.message ("Node "+parent.node_name+" has childs? "+current_has_childs ().to_string ());
#endif
    if (!current_has_childs ()) return;
    bool cont = true;
    while (cont) {
      if (!move_next_node ()) return;
#if DEBUG
      GLib.message ("Current child node: "+current_node_name ());
#endif
      if (current_is_element ())
        cont = read_child_element (parent);
      else
        cont = read_child_node (parent);
    }
  }
  /**
   * Creates a new {@link DomNode} and append it to
   * parent: depending on current node's type found by parser.
   *
   * If current found node is a {@link DomElement}, it is not parsed.
   * If you want to parse it use {@link parse_element} method.
   *
   * Returns: true if node has been created and appended to parent.
   */
  public bool read_child_node (DomNode parent) {
    DomNode n = null;
    var t = tr.node_type ();
    switch (t) {
    case Xml.ReaderType.NONE:
#if DEBUG
      GLib.message ("Type NONE");
#endif
      move_next_node ();
      break;
    case Xml.ReaderType.ATTRIBUTE:
#if DEBUG
      GLib.message ("Type ATTRIBUTE");
#endif
      break;
    case Xml.ReaderType.TEXT:
      var txtval = tr.read_string ();
#if DEBUG
      GLib.message ("Type TEXT");
      GLib.message ("ReadNode: Text Node : '"+txtval+"'");
#endif
      n = _document.create_text_node (txtval);
      parent.append_child (n);
      break;
    case Xml.ReaderType.CDATA:
      break;
    case Xml.ReaderType.ENTITY_REFERENCE:
#if DEBUG
      GLib.message ("Type ENTITY_REFERENCE");
#endif
      break;
    case Xml.ReaderType.ENTITY:
#if DEBUG
      GLib.message ("Type ENTITY");
#endif
      break;
    case Xml.ReaderType.PROCESSING_INSTRUCTION:
      var pit = tr.const_local_name ();
      var pival = tr.value ();
#if DEBUG
      GLib.message ("Type PROCESSING_INSTRUCTION");
      GLib.message ("ReadNode: PI Node : '"+pit+"' : '"+pival+"'");
#endif
      n = _document.create_processing_instruction (pit,pival);
      parent.append_child (n);
      break;
    case Xml.ReaderType.COMMENT:
      var commval = tr.value ();
#if DEBUG
      GLib.message ("Type COMMENT");
      GLib.message ("ReadNode: Comment Node : '"+commval+"'");
#endif
      n = _document.create_comment (commval);
      parent.append_child (n);
      break;
    case Xml.ReaderType.DOCUMENT:
#if DEBUG
      GLib.message ("Type DOCUMENT");
#endif
      return false;
      break;
    case Xml.ReaderType.DOCUMENT_TYPE:
#if DEBUG
      GLib.message ("Type DOCUMENT_TYPE");
#endif
      return false;
      break;
    case Xml.ReaderType.DOCUMENT_FRAGMENT:
#if DEBUG
      GLib.message ("Type DOCUMENT_FRAGMENT");
#endif
      return false;
      break;
    case Xml.ReaderType.NOTATION:
#if DEBUG
      GLib.message ("Type NOTATION");
#endif
      break;
    case Xml.ReaderType.WHITESPACE:
#if DEBUG
      GLib.message ("Type WHITESPACE");
#endif
      break;
    case Xml.ReaderType.SIGNIFICANT_WHITESPACE:
      var stxtval = tr.read_string ();
#if DEBUG
      GLib.message ("ReadNode: Text Node : '"+stxtval+"'");
      GLib.message ("Type SIGNIFICANT_WHITESPACE");
#endif
      n = _document.create_text_node (stxtval);
      parent.append_child (n);
      break;
    case Xml.ReaderType.END_ELEMENT:
#if DEBUG
      GLib.message ("Type END_ELEMENT");
#endif
      return false;
    case Xml.ReaderType.END_ENTITY:
#if DEBUG
      GLib.message ("Type END_ENTITY");
#endif
      return false;
    case Xml.ReaderType.XML_DECLARATION:
#if DEBUG
      GLib.message ("Type XML_DECLARATION");
#endif
      return false;
      break;
    case Xml.ReaderType.ELEMENT:
      return false;
      break;
    }
    return true;
  }
  /**
   * Reads current found element
   */
  public bool read_child_element (DomNode parent) throws GLib.Error {
    if (!current_is_element ())
      throw new DomError.INVALID_NODE_TYPE_ERROR
        (_("Invalid attempt to parse an element node, when current found node is not"));
#if DEBUG
    GLib.message ("Parsing Child ELEMENT: "+current_node_name ()+" NODE to parent: "+parent.node_name);
#endif
    DomNode n = null;
    if (!read_element_property (parent, out n))
      n = create_element (parent);
    if (n == null) return false;
#if DEBUG
    GLib.message ("Reading New Node: "+n.node_name);
#endif
    read_element (n as DomElement);
    read_child_nodes (n);
    return true;
  }
  /**
   * Creates a new {@link DomElement} and append it as a child of parent: for current
   * read node, only if :
   *
   * # parent: have a property as {@link DomElement} type and current
   * node have same local name as property element.
   * # parent: have a property as {@link GomCollection} type and current
   * node have same local name as collection {@link GomCollection.items_name}
   *
   * Returns: true if element is set to a new object, it is set as a parent:
   * property or has been added to a parent: collection property.
   */
  public bool read_element_property (DomNode parent,
                  out DomNode element) throws GLib.Error {
    if (!(parent is GomObject)) return false;
#if DEBUG
    GLib.message ("Searching for Properties Nodes for:"+
                  (parent as DomElement).local_name+
                  " Current node name: "+ tr.const_local_name ());
#endif
    foreach (ParamSpec pspec in
              (parent as GomObject).get_property_element_list ()) {
      if (pspec.value_type.is_a (typeof (GomCollection))) {
#if DEBUG
        GLib.message (" Is Collection in: "+(parent as DomElement).local_name);
#endif
        GomCollection col;
        Value vc = Value (pspec.value_type);
        parent.get_property (pspec.name, ref vc);
        col = vc.get_object () as GomCollection;
        if (col == null) {
#if DEBUG
          GLib.message ("Initializing Collection property...");
#endif
          col = Object.new (pspec.value_type,
                            "element", parent) as GomCollection;
          vc.set_object (col);
          parent.set_property (pspec.name, vc);
        }
        if (col.items_type == GLib.Type.INVALID
            || !(col.items_type.is_a (typeof (GomObject)))) {
          throw new DomError.INVALID_NODE_TYPE_ERROR
                      (_("Invalid object type set to Collection"));
        }
        if (col.items_name == "" || col.items_name == null) {
          throw new DomError.INVALID_NODE_TYPE_ERROR
                      (_("Invalid DomElement name for objects in Collection"));
        }
        if (col.element == null || !(col.element is GomElement)) {
          throw new DomError.INVALID_NODE_TYPE_ERROR
                      (_("Invalid Element set to Collection"));
        }
        if (col.items_name.down () == tr.const_local_name ().down ()) {
#if DEBUG
          GLib.message ("Is a Node to append in collection");
#endif
          if (parent.owner_document == null)
            throw new DomError.HIERARCHY_REQUEST_ERROR
                        (_("No document is set to node"));
          var obj = Object.new (col.items_type,
                                "owner-document", _document);
#if DEBUG
          GLib.message ("Object Element to add in Collection: "
                          +(_node as DomNode).node_name);
#endif
          col.append (obj as DomElement);
          element = obj as DomNode;
          return true;
        }
      } else {
        var obj = Object.new (pspec.value_type,
                              "owner-document", _document);
        if ((obj as DomElement).local_name.down ()
               == tr.const_local_name ().down ()) {
          Value v = Value (pspec.value_type);
          read_current_node (obj as DomNode, true, true);
          parent.append_child (obj as DomNode);
          v.set_object (obj);
          parent.set_property (pspec.name, v);
          element = obj as DomNode;
          return true;
        }
      }
    }
    return false;
  }
  public bool read_current_node (DomNode node,
                                bool read_current = false,
                                bool read_property = false)
                                throws GLib.Error {
    GXml.DomNode n = node;
    string prefix = null, nsuri = null;
    int res = 1;
#if DEBUG
    GLib.message ("ReadNode: Current Node: "+node.node_name
                  +" Current: "+read_current.to_string ()+
                  " Property: "+read_property.to_string ());
#endif
    if (!read_property) {
      res = tr.read ();
      if (res == -1)
        throw new ParserError.INVALID_DATA_ERROR (_("Can't read node data"));
#if DEBUG
      if (res == 0)
        GLib.message ("ReadNode: No more nodes");
#endif
      if (res == 0) return false;
    }
    var t = tr.node_type ();
    switch (t) {
    case Xml.ReaderType.NONE:
#if DEBUG
      GLib.message ("Type NONE");
#endif
      res = tr.read ();
      if (res == -1)
        throw new ParserError.INVALID_DATA_ERROR (_("Can't read node data"));
      break;
    case Xml.ReaderType.ELEMENT:
      bool isproperty = false;
      bool isempty = (tr.is_empty_element () == 1);
      if (!read_current && !read_property
          && node is DomElement
          && tr.const_local_name () != (node as DomElement).local_name) {
#if DEBUG
        GLib.message ("Searching for Properties Nodes for:"+
                      (node as DomElement).local_name+
                      " Current node name: "+ tr.const_local_name ());
#endif
        foreach (ParamSpec pspec in
                  (node as GomObject).get_property_element_list ()) {
          if (pspec.value_type.is_a (typeof (GomCollection))) {
#if DEBUG
            GLib.message (" Is Collection in: "+(node as DomElement).local_name);
#endif
            GomCollection col;
            Value vc = Value (pspec.value_type);
            node.get_property (pspec.name, ref vc);
            col = vc.get_object () as GomCollection;
            if (col == null) {
#if DEBUG
              GLib.message ("Initializing Collection property...");
#endif
              col = Object.new (pspec.value_type,
                                "element", node) as GomCollection;
              vc.set_object (col);
              node.set_property (pspec.name, vc);
            }
            if (col.items_type == GLib.Type.INVALID
                || !(col.items_type.is_a (typeof (GomObject)))) {
              throw new DomError.INVALID_NODE_TYPE_ERROR
                          (_("Invalid object type set to Collection"));
              continue;
            }
            if (col.items_name == "" || col.items_name == null) {
              throw new DomError.INVALID_NODE_TYPE_ERROR
                          (_("Invalid DomElement name for objects in Collection"));
              continue;
            }
            if (col.element == null || !(col.element is GomElement)) {
              throw new DomError.INVALID_NODE_TYPE_ERROR
                          (_("Invalid Element set to Collection"));
              continue;
            }
            if (col.items_name.down () == tr.const_local_name ().down ()) {
#if DEBUG
              GLib.message ("Is a Node to append in collection");
#endif
              if (node.owner_document == null)
                throw new DomError.HIERARCHY_REQUEST_ERROR
                            (_("No document is set to node"));
              var obj = Object.new (col.items_type,
                                    "owner-document", _document);
#if DEBUG
              GLib.message ("Equal Documents:"+
                  ((obj as DomNode).owner_document == node.owner_document).to_string ());
              GLib.message ("Object Element to add in Collection: "
                              +(_node as DomNode).node_name);
              GLib.message ("Root Document Element Root: "
                            +(_node as DomNode).owner_document.document_element.node_name);
              GLib.message ("Root Document Element Node: "
                            +(node as DomNode).owner_document.document_element.node_name);
              GLib.message ("Root Document Element: "
                            +(obj as DomNode).owner_document.document_element.node_name);
#endif
              read_current_node (obj as DomNode, true, true);
#if DEBUG
              GLib.message ("Adding element to collection...");
#endif
              col.append (obj as DomElement);
              isproperty = true;
              break;
            }
          } else {
            var obj = Object.new (pspec.value_type,
                                  "owner-document", _document);
            if ((obj as DomElement).local_name.down ()
                   == tr.const_local_name ().down ()) {
              Value v = Value (pspec.value_type);
              read_current_node (obj as DomNode, true, true);
              node.append_child (obj as DomNode);
              v.set_object (obj);
              node.set_property (pspec.name, v);
              isproperty = true;
              break;
            }
          }
        }
      }
      if (node is DomElement) {
        if (read_current
            && tr.const_local_name ().down ()
                != (node as DomElement).local_name.down ())
          throw new DomError.VALIDATION_ERROR
                    (_("Invalid element node name. Expected %s")
                        .printf ((node as DomElement).local_name));
      }
      if (!isproperty) {
        if (node is DomDocument || !read_current) {
#if DEBUG
          GLib.message ("No object Property is set. Creating a standard element: "
                        +tr.const_local_name ());
          GLib.message ("No deserializing current node");
          if (isempty) GLib.message ("Is Empty node:"+node.node_name);
          GLib.message ("ReadNode: Element: "+tr.const_local_name ());
#endif
          if (!isproperty) {
            prefix = tr.prefix ();
            if (prefix != null) {
#if DEBUG
              GLib.message ("Is namespaced element");
#endif
              nsuri = tr.lookup_namespace (prefix);
              n = _document.create_element_ns (nsuri, tr.prefix () +":"+ tr.const_local_name ());
            } else
              n = _document.create_element (tr.const_local_name ());
            node.append_child (n);
          }
        }
        var nattr = tr.attribute_count ();
#if DEBUG
        GLib.message ("Number of Attributes:"+nattr.to_string ());
#endif
        for (int i = 0; i < nattr; i++) {
          var c = tr.move_to_attribute_no (i);
#if DEBUG
          GLib.message ("Current Attribute: "+i.to_string ());
#endif
          if (c != 1) {
            throw new DomError.HIERARCHY_REQUEST_ERROR (_("Parsing ERROR: Fail to move to attribute number: %i").printf (i));
          }
          if (tr.is_namespace_decl () == 1) {
#if DEBUG
            GLib.message ("Is Namespace Declaration...");
#endif
            string nsp = tr.const_local_name ();
            string aprefix = tr.prefix ();
            tr.read_attribute_value ();
            if (tr.node_type () == Xml.ReaderType.TEXT) {
              string ansuri = tr.read_string ();
#if DEBUG
              GLib.message ("Read: "+aprefix+":"+nsp+"="+ansuri);
#endif
              string ansp = nsp;
              if (nsp != "xmlns")
                ansp = aprefix+":"+nsp;
#if DEBUG
              GLib.message ("To append: "+ansp+"="+ansuri);
#endif
              (n as DomElement).set_attribute_ns ("http://www.w3.org/2000/xmlns/",
                                                   ansp, ansuri);
            }
          } else {
            var attrname = tr.const_local_name ();
            prefix = tr.prefix ();
#if DEBUG
            GLib.message ("Attribute: "+tr.const_local_name ());
#endif
            tr.read_attribute_value ();
            if (tr.node_type () == Xml.ReaderType.TEXT) {
              var attrval = tr.read_string ();
#if DEBUG
              GLib.message ("Attribute:"+attrname+" Value: "+attrval);
#endif
              bool processed = (n as GomObject).set_attribute (attrname, attrval);
              if (prefix != null && !processed) {
#if DEBUG
                GLib.message ("Prefix found: "+prefix);
#endif
                if (prefix == "xml")
                  nsuri = "http://www.w3.org/2000/xmlns/";
                else
                  nsuri = tr.lookup_namespace (prefix);
                (n as DomElement).set_attribute_ns (nsuri, prefix+":"+attrname, attrval);
              } else if (!processed)
                (n as DomElement).set_attribute (attrname, attrval);
            }
          }
        }
#if DEBUG
        GLib.message ("No more element attributes for: "
                        +node.node_name);
#endif
      }
      if (isempty) {
#if DEBUG
        GLib.message ("No child nodes returning...");
#endif
        return true;
      }
#if DEBUG
      GLib.message ("Getting child nodes in element");
#endif
      while (read_current_node (n) == true);
      break;
    case Xml.ReaderType.ATTRIBUTE:
#if DEBUG
      GLib.message ("Type ATTRIBUTE");
#endif
      break;
    case Xml.ReaderType.TEXT:
      var txtval = tr.read_string ();
#if DEBUG
      GLib.message ("Type TEXT");
      GLib.message ("ReadNode: Text Node : '"+txtval+"'");
#endif
      n = _document.create_text_node (txtval);
      node.append_child (n);
      break;
    case Xml.ReaderType.CDATA:
      break;
    case Xml.ReaderType.ENTITY_REFERENCE:
#if DEBUG
      GLib.message ("Type ENTITY_REFERENCE");
#endif
      break;
    case Xml.ReaderType.ENTITY:
#if DEBUG
      GLib.message ("Type ENTITY");
#endif
      break;
    case Xml.ReaderType.PROCESSING_INSTRUCTION:
      var pit = tr.const_local_name ();
      var pival = tr.value ();
#if DEBUG
      GLib.message ("Type PROCESSING_INSTRUCTION");
      GLib.message ("ReadNode: PI Node : '"+pit+"' : '"+pival+"'");
#endif
      n = node.owner_document.create_processing_instruction (pit,pival);
      node.append_child (n);
      break;
    case Xml.ReaderType.COMMENT:
      var commval = tr.value ();
#if DEBUG
      GLib.message ("Type COMMENT");
      GLib.message ("ReadNode: Comment Node : '"+commval+"'");
#endif
      n = node.owner_document.create_comment (commval);
      node.append_child (n);
      break;
    case Xml.ReaderType.DOCUMENT:
#if DEBUG
      GLib.message ("Type DOCUMENT");
#endif
      break;
    case Xml.ReaderType.DOCUMENT_TYPE:
#if DEBUG
      GLib.message ("Type DOCUMENT_TYPE");
#endif
      break;
    case Xml.ReaderType.DOCUMENT_FRAGMENT:
#if DEBUG
      GLib.message ("Type DOCUMENT_FRAGMENT");
#endif
      break;
    case Xml.ReaderType.NOTATION:
#if DEBUG
      GLib.message ("Type NOTATION");
#endif
      break;
    case Xml.ReaderType.WHITESPACE:
#if DEBUG
      GLib.message ("Type WHITESPACE");
#endif
      break;
    case Xml.ReaderType.SIGNIFICANT_WHITESPACE:
      var stxtval = tr.read_string ();
#if DEBUG
      GLib.message ("ReadNode: Text Node : '"+stxtval+"'");
      GLib.message ("Type SIGNIFICANT_WHITESPACE");
#endif
      n = _document.create_text_node (stxtval);
      node.append_child (n);
      break;
    case Xml.ReaderType.END_ELEMENT:
#if DEBUG
      GLib.message ("Type END_ELEMENT");
#endif
      return false;
    case Xml.ReaderType.END_ENTITY:
#if DEBUG
      GLib.message ("Type END_ENTITY");
#endif
      return false;
    case Xml.ReaderType.XML_DECLARATION:
#if DEBUG
      GLib.message ("Type XML_DECLARATION");
#endif
      break;
    }
    return true;
  }

  private string dump () throws GLib.Error {
    int size;
    Xml.Doc doc = new Xml.Doc ();
    tw = Xmlx.new_text_writer_doc (ref doc);
    if (_node is DomDocument) tw.start_document ();
    tw.set_indent (indent);
    // Root
    if (_node is DomDocument) {
      if ((node as DomDocument).document_element == null) {
        tw.end_document ();
      }
    }
#if DEBUG
    GLib.message ("Starting writting Document child nodes");
#endif
    start_node (_node);
#if DEBUG
    GLib.message ("Ending writting Document child nodes");
#endif
    tw.end_element ();
#if DEBUG
    GLib.message ("Ending Document");
#endif
    tw.end_document ();
    tw.flush ();
    string str;
    doc.dump_memory (out str, out size);
#if DEBUG
    if (str != null)
      GLib.message ("STR: "+str);
#endif
    return str;
  }
  private void start_node (GXml.DomNode node)
    throws GLib.Error
  {
#if DEBUG
    GLib.message ("Starting node..."+node.node_name);
#endif
    int size = 0;
#if DEBUG
    GLib.message (@"Starting Node: start Node: '$(node.node_name)'");
#endif
    if (node is GXml.DomElement) {
#if DEBUG
      GLib.message (@"Starting Element... '$(node.node_name)'");
      GLib.message (@"Element Document is Null... '$((node.owner_document == null).to_string ())'");
#endif
      if ((node as DomElement).prefix != null
          || (node as DomElement).namespace_uri != null) {
        string name = (node as DomElement).prefix
                      + ":" + (node as DomElement).local_name;
        tw.start_element (name);
      }
      if ((node as DomElement).prefix == null
            && (node as DomElement).namespace_uri != null) {
#if DEBUG
            GLib.message ("Writting namespace definition for node");
#endif
          tw.start_element_ns (null,
                               (node as DomElement).local_name,
                               (node as DomElement).namespace_uri);
      } else
        tw.start_element (node.node_name);
#if DEBUG
    GLib.message ("Write down properties: size:"+(node as DomElement).attributes.size.to_string ());
#endif

    // GomObject serialization
    var lp = (node as GomObject).get_properties_list ();
    foreach (string pk in lp) {
      string v = (node as GomObject).get_attribute (pk);
      if (v == null) continue;
      size += tw.write_attribute (pk, v);
      size += tw.end_attribute ();
      if (size > 1500)
        tw.flush ();
    }
    // GomProperty serialization
    var lps = (node as GomObject).get_object_properties_list ();
    foreach (ParamSpec pspec in lps) {
      Value v = Value (pspec.value_type);
      node.get_property (pspec.name, ref v);
      GomProperty gp = v.get_object () as GomProperty;
      if (gp == null) continue;
      size += tw.write_attribute (gp.attribute_name, gp.value);
      size += tw.end_attribute ();
      if (size > 1500)
        tw.flush ();
    }
    // DomElement attributes
    foreach (string ak in (node as DomElement).attributes.keys) {
      string v = ((node as DomElement).attributes as HashMap<string,string>).get (ak);
      size += tw.write_attribute (ak, v);
      size += tw.end_attribute ();
      if (size > 1500)
        tw.flush ();
    }
  }
  // Non Elements
#if DEBUG
    GLib.message (@"Starting Element: writting Node '$(node.node_name)' children");
#endif
    foreach (GXml.DomNode n in node.child_nodes) {
#if DEBUG
      GLib.message (@"Child Node is: $(n.get_type ().name ())");
#endif
      if (n is GXml.DomElement) {
#if DEBUG
      GLib.message (@"Starting Child Element: writting Node '$(n.node_name)'");
#endif
        start_node (n);
        size += tw.end_element ();
        if (size > 1500)
          tw.flush ();
      }
      if (n is GXml.DomText) {
#if DEBUG
      GLib.message ("Writting Element's contents");
#endif
      size += tw.write_string (n.node_value);
      if (size > 1500)
        tw.flush ();
      }
      if (n is GXml.DomComment) {
#if DEBUG
      GLib.message (@"Starting Child Element: writting Comment '$(n.node_value)'");
#endif
        size += tw.write_comment (n.node_value);
        if (size > 1500)
          tw.flush ();
      }
      if (n is GXml.DomProcessingInstruction) {
  #if DEBUG
      GLib.message (@"Starting Child Element: writting ProcessingInstruction '$(n.node_value)'");
  #endif
        size += Xmlx.text_writer_write_pi (tw, (n as DomProcessingInstruction).target,
                                          (n as DomProcessingInstruction).data);
        if (size > 1500)
          tw.flush ();
      }
    }
  }
}
