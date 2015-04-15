/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 2 -*- */
/* BackedNode.vala
 *
 * Copyright (C) 2011-2013  Richard Schwarting <aquarichy@gmail.com>
 * Copyright (C) 2011,2015  Daniel Espinosa <esodan@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Authors:
 *      Richard Schwarting <aquarichy@gmail.com>
 *      Daniel Espinosa <esodan@gmail.com>
 */

// NOTE: be careful about what extra data subclasses keep

namespace GXml {
	/**
	 * An internal class for nodes whose content is stored in a
	 * corresponding Xml.Node.
	 * 
	 * This would normally be hidden, but Vala wants base classes
	 * to be at least as public as subclasses.
	 */
	public class BackedNode : xNode {
		/** Private properties */
		internal Xml.Node *node;

		internal void set_xmlnode (Xml.Node *node, xDocument owner) {
			this.node = node;
			owner.node_dict.insert (node, this);
		}

		/* Constructors */
		internal BackedNode (Xml.Node *node, xDocument owner) {
			base ((NodeType)node->type, owner);

			// Save the correspondence between this Xml.Node* and its Node
			this.set_xmlnode (node, owner);
			// TODO: Consider checking whether the Xml.Node* is already recorded.  It shouldn't be.
			// TODO: BackedNodes' memory are freed when their owner document is freed; let's make sure that when we move a node between documents, that we make sure they'll still be freed
		}


		/* Public properties */

		private NamespaceAttrNodeList _namespace_definitions = null;
		/**
		 * {@inheritDoc}
		 */
		public override NodeList? namespace_definitions {
			get {
				if (_namespace_definitions == null) {
					this._namespace_definitions = new NamespaceAttrNodeList (this, this.owner_document);
				}
				return this._namespace_definitions;
			}
			internal set {
			}
		}

		/**
		 * {@inheritDoc}
		 */
		public override string? namespace_uri {
			get {
				// TODO: there can be multiple NSes on a node, using ->next, right now we just return the first.  What should we do?!?!
				if (this.node->ns == null) {
					return null;
				} else {
					return this.node->ns->href;
				}
			}
			internal set {
			}
		}
		/**
		 * {@inheritDoc}
		 */
		public override NamespaceAttr? add_namespace_attr (string uri, string namespace_prefix)
		{
			//stdout.printf ("BackedNode: Before add new Namespace\n");
			var ns = this.node->new_ns (uri, namespace_prefix);
			if (ns == null)
				return null;
			else
				return new NamespaceAttr (ns, owner_document);
		}
		/**
		 * {@inheritDoc}
		 */
		public override bool set_namespace (string uri, string namespace_prefix)
		{
			if (node == null) return false;
			if (node->ns_def != null) {
				for (Xml.Ns *cur = node->ns_def; cur != null; cur = cur->next) {
					if ((string) cur->prefix == namespace_prefix && (string) cur->href == uri) {
						node->set_ns (cur);
						return true;
					}
				}
			}
			// Not found search on parent
			if (node->parent != null) {
				for (Xml.Ns *cur = node->parent->ns_def; cur != null; cur = cur->next) {
					if ((string) cur->prefix == namespace_prefix && (string) cur->href == uri) {
						this.node->set_ns (cur);
						return true;
					}
				}
			}
			// Not found in this node, searching on root element
			if (owner_document == null) return false;
			if (owner_document.document_element == null) return false;
			if (owner_document.document_element.node == null) return false;
			if (owner_document.document_element.node->ns_def == null) return false;
			for (Xml.Ns *cur = owner_document.document_element.node->ns_def; cur != null; cur = cur->next) {
				if ((string) cur->prefix == namespace_prefix && (string) cur->href == uri) {
					this.node->set_ns (cur);
					return true;
				}
			}
			return false;
		}
		/**
		 * {@inheritDoc}
		 */
		public override string? namespace_prefix {
			get {
				if (this.node->ns == null) {
					return null;
				} else {
					return this.node->ns->prefix;
				}
			}
			internal set {
			}
		}
		/**
		 * {@inheritDoc}
		 */
		public override string? local_name {
			get {
				return this.node_name;
			}
			internal set {
			}
		}

		/* None of the following should store any data locally (except the attribute table), they should get data from Xml.Node* */

		// TODO: make sure that subclasses obey the table in Node for node_name, node_value, and attributes; probably figure it out as I create tests for them.
		/**
		 * {@inheritDoc}
		 */
		public override string node_name {
			get {
				return this.node->name;
			}
			internal set {
			}
		}

		/**
		 * {@inheritDoc}
		 */
		public override string? node_value {
			get {
				return this.node->content;
			}
			internal set {
				/* NOTE: this is mainly for Text and CharacterData, many other
				         Nodes really want to edit children, but hopefully they
				         override node_value anyway. */
				this.node->content = value;
			}
		}
		//  {
			// get {
			// 	// TODO: where is this typically stored?
			// 	// TODO: if it's an Element, it should return null, as all its 'value' is in its children
			// 	return this.node->content; // TODO: same as value here?
			// }
			// internal set {
			// 	this.node->children->content = value;
			// }
		//}/* "raises [DomError] on setting/retrieval"?  */
		/**
		 * {@inheritDoc}
		 */
		public override NodeType node_type {
			get {
				/* Right now, Dom.NodeType's 12 values map perfectly to libxml2's first 12 types */
				return (NodeType)this.node->type;
			}
			internal set {
			}
			// default = NodeType.ELEMENT;
		}
		/**
		 * {@inheritDoc}
		 */
		public override xNode? parent_node {
			get {
				return this.owner_document.lookup_node (this.node->parent);
				// TODO: is parent never null? parent is probably possible to be null, like when you create a new element unattached
				// return new Node (this.node->parent);
				// TODO: figure out whether we really want to recreate wrapper objects each time
			}
			internal set {
			}
		}
		/* TODO: just used unowned to avoid compilation error for stub; investigate what's right */
		// TODO: need to let the user know that editing this list doesn't add children to the node (but then what should?)
		/* NOTE: try to avoid using this too often internally, would be much quicker to
		   just traverse Xml.Node*'s children */
		/**
		 * {@inheritDoc}
		 */
		public override NodeList? child_nodes {
			owned get {
				// TODO: always create a new one?
				return new NodeChildNodeList (this.node, this.owner_document);
			}
			internal set {
			}
		}

		private xNode? _first_child;
		/**
		 * {@inheritDoc}
		 */
		public override xNode? first_child {
			get {
				_first_child = this.child_nodes.first ();
				return _first_child;
			}
			internal set {
			}
		}

		private xNode? _last_child;
		/**
		 * {@inheritDoc}
		 */
		public override xNode? last_child {
			get {
				_last_child = this.child_nodes.last ();
				return _last_child;
			}
			internal set {
			}
		}
		/**
		 * {@inheritDoc}
		 */
		public override xNode? previous_sibling {
			get {
				return this.owner_document.lookup_node (this.node->prev);
			}
			internal set {
			}
		}
		/**
		 * {@inheritDoc}
		 */
		public override xNode? next_sibling {
			get {
				return this.owner_document.lookup_node (this.node->next);
			}
			internal set {
			}
		}

		// TODO: investigate which classes can have children;
		//       e.g. Text shouldn't, and these should error if we try;
		//       how does libxml2 handle it?  test that

		/**
		 * {@inheritDoc}
		 */
		public override unowned xNode? insert_before (xNode new_child, xNode? ref_child) {
			return this.child_nodes.insert_before (new_child, ref_child);
		}
		/**
		 * {@inheritDoc}
		 */
		public override unowned xNode? replace_child (xNode new_child, xNode old_child) {
			return this.child_nodes.replace_child (new_child, old_child);
		}

		/**
		 * {@inheritDoc}
		 */
		public override unowned xNode? remove_child (xNode old_child) {
			return this.child_nodes.remove_child (old_child);
		}

		/**
		 * {@inheritDoc}
		 */
		public override unowned xNode? append_child (xNode new_child) {
			if (new_child.owner_document != this.owner_document && new_child.get_type ().is_a (typeof (GXml.BackedNode))) {
				/* The point here is that a node from another document should
				   have a copy made to be integrated into this one, so we
				   don't mess up the other document.  (TODO: consider
				   removing it from the originating document.)  The node's
				   references should be updated to this one. */
				return this.child_nodes.append_child (this.owner_document.copy_node (new_child));
			} else {
				return this.child_nodes.append_child (new_child);
			}
		}
		/**
		 * {@inheritDoc}
		 */
		public override bool has_child_nodes () {
			return (this.child_nodes.length > 0);
		}

		/**
		 * {@inheritDoc}
		 */
		public override unowned xNode? clone_node (bool deep) {
			return this.owner_document.copy_node (this, deep);
			// TODO: add a better test, as we weren't realising this was just a stub; test for memory usage too
		}

		public override string to_string (bool format = true, int level = 0) {
			/* TODO: change from xmlNodeDump and xmlBuffer
			 * to xmlBuf and xmlBufNodeDump; the former
			 * are 'somehow deprecated' (see xmlNodeDump
			 * doc); however, it's unclear how to create
			 * an xmlBuf right now : \ */
			/* TODO: Consider loading documents with
			 * xmlKeepBlanksDefault(0) that would cause a
			 * loaded document to lose all of its blank
			 * space (space between <> and a
			 * non-whitespace) when loaded, allowing us to
			 * use format with xmlNodeDump in cases where
			 * the document contains a Text (format is
			 * ignored if Text is contained).  This is
			 * probably a bad idea; we probably want to
			 * retain the whitespace we load with, and
			 * instead we might need to find some other
			 * way to implement formatting well. */
			Xml.Buffer *buffer;
			string str;

			buffer = new Xml.Buffer ();
			buffer->node_dump (this.owner_document.xmldoc, this.node, level, format ? 1 : 0);
			str = buffer->content ();
			return str;
		}
		// GXml.Node interface implementations
		public Gee.LinkedList<GXml.Namespace> namespaces
		{
			get {
				return _namespace_definitions;
			}
		}
		/*
		public Gee.LinkedList<GXml.Node> childs
		{
			get {
				
			}
		}
		public Gee.Map<string,GXml.Node> attrs { get; }
		public string name { get; construct set; }
		public string @value { get; set; }
		public GXml.NodeType type_node { get; construct set; }
		public GXml.Document document { get; construct set; }
		public GXml.Node copy ();
		public string to_string ();*/
	}
}