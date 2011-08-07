/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */

namespace GXml.Dom {
	/* TODO: consider adding public signals for new/deleted children */

	/**
	 * Represents an XML Node. Documents are nodes, and are
	 * composed of a tree of nodes. See [[http://www.w3.org/TR/DOM-Level-1/level-one-core.html#ID-1950641247]]
	 */
	public class XNode : GLib.Object {
		internal XNode (NodeType type, Document owner) {
			this.node_type = type;
			this.owner_document = owner;
		}
		internal XNode.for_document () {
			this.node_name = "#document";
			this.node_type = NodeType.DOCUMENT;
		}

		/**
		 * Stores the value of the Node. The nature of
		 * node_value varies based on the type of node. This
		 * can be null.
		 */
		public virtual string? node_value {
			get {
				return null;
			}
			internal set {
			}
		}

		/**
		 * Stores the name of the node. Sometimes this is
		 * similar to the node type, but sometimes, it is
		 * arbitrary.
		 */
		public virtual string node_name {
			get; internal set;
		}


		private NodeType _node_type;
		/**
		 * Stores the type of node. Most XML structures are
		 * nodes of different types, like Document, Attr,
		 * Element, etc.
		 */
		public virtual NodeType node_type {
			get {
				return _node_type;
			}
				// return  (NodeType)this.node->type; // TODO: Same type?  Do we want to upgrade ushort to ElementType?
			//}
			internal set {
				this._node_type = value;
			}
		}

		/**
		 * A link to the Document to which this node belongs.
		 */
		public Document owner_document {
			get;
			internal set;
		}

		// TODO: declare more of interface here
		/**
		 * A link to the parent of this node. For example,
		 * with elements, the immediate, outer element is the parent.
		 * <parent><child></child></parent>
		 */
		public virtual XNode? parent_node {
			get { return null; }
			internal set {}
		}
		/**
		 * List of child nodes to this node. These sometimes
		 * represent the value of a node as a tree of values,
		 * whereas node_value represents it as a string. This
		 * can be null for node types that have no children.
		 *
		 * The NodeList is live, in that changes to this
		 * node's children will be reflected in an
		 * already-active NodeList.
		 *
		 * #todo: list nodes that use children for values
		 */
		public virtual NodeList? child_nodes {
			// TODO: need to implement NodeList
			owned get { return null; }
			internal set {}
		}
		/**
		 * Links to the first child. If there are no
		 * children, it returns null.
		 */
		public virtual XNode? first_child {
			get { return null; }
			internal set {}
		}
		/**
		 * Links to the last child. If there are no
		 * children, it returns null.
		 */
		public virtual XNode? last_child {
			get { return null; }
			internal set {}
		}
		/**
		 * Links to this node's preceding sibling. If there
		 * are no previous siblings, it returns null. Note
		 * that the children of a node are ordered.
		 */
		public virtual XNode? previous_sibling {
			get { return null; }
			internal set {}
		}
		/**
		 * Links to this node's next sibling. If there is no
		 * next sibling, it returns null. Note that the
		 * children of a node are ordered.
		 */
		public virtual XNode? next_sibling {
			get { return null; }
			internal set {}
		}
		/**
		 * Returns a HashTable representing the attributes for
		 * this node. Attributes actually only apply to
		 * Element nodes. For all other types, attributes is
		 * null.
		 */
		public virtual HashTable<string,Attr>? attributes {
			get { return null; }
			internal set {}
		}

		// These may need to be overridden by subclasses that support them.
		// TODO: figure out what non-BackedNode classes should be doing with these, anyway
		/**
		 * Insert new_child as a child to this node, and place
		 * it in the list before ref_child. If ref_child is
		 * null, new_child is appended to the list of children
		 * instead.
		 *
		 * @throws DomError.NOT_FOUND if ref_child is not a valid child.
		 */
		// #todo: want to throw other relevant errors
		public virtual XNode? insert_before (XNode new_child, XNode? ref_child) throws DomError {
			return null;
		}
		/**
		 * Replaces old_child with new_child in this node's list of children.
		 *
		 * @return The removed old_child.
		 *
		 * @throws DomError.NOT_FOUND if ref_child is not a valid child.
		 */
		public virtual XNode? replace_child (XNode new_child, XNode old_child) throws DomError {
			return null;
		}
		/**
		 * Removes old_child from this node's list of children.
		 *
		 * @return The removed old_child.
		 *
		 * @throws DomError.NOT_FOUND if old_child is not a valid child.
		 * #todo: make @throws claim true
		 */
		public virtual XNode? remove_child (XNode old_child) throws DomError {
			return null;
		}
		/**
		 * Appends new_child to the end of this node's list of children.
		 *
		 * @return The newly added child.
		 */
		public virtual XNode? append_child (XNode new_child) throws DomError {
			return null;
		}
		/**
		 * Indicates whether this node has children.
		 */
		public virtual bool has_child_nodes () {
			return false;
		}
		/**
		 * Creates a parentless copy of this node.
		 *
		 * @param deep If true, descendants are cloned as
		 * well. If false, they are not.
		 *
		 * @return A parentless clone of this node.
		 */
		public virtual XNode? clone_nodes (bool deep) {
			return null;
		}

		private string _str;
		/**
		 * Provides a string representation of this node.
		 *
		 * @param format false: no formatting, true: formatted, with indentation
		 * @param level Indentation level
		 *
		 * @return XML string for node.
		 */
		// TODO: need to investigate how to activate format
		public virtual string to_string (bool format = false, int level = 0) {
			_str = "XNode(%d:%s)".printf (this.node_type, this.node_name);
			return _str;
		}
	}
}

