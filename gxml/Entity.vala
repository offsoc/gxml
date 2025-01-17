/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
namespace GXml {
	/**
	 * The content referenced by an {@link GXml.EntityReference}, and defined
	 * in a {@link GXml.DocumentType}.
	 * 
	 * For more, see: [[http://www.w3.org/TR/DOM-Level-1/level-one-core.html#ID-11C98490]]
	 */
	public class Entity : DomNode {
		private Xml.Entity *entity;

		/**
		 * A public identifier for the entity. `null` when unspecified.
		 */ // TODO: how are these used?
		public string public_id {
			get {
				//return this.entity->external_id; // TODO: fix libxml2 wrapper
				return "";
			}
			private set {
			}
		}
		/**
		 * A system identifier for the entity. `null` when unspecified.
		 */
		public string system_id {
			get {
				// return this.entity->system_id; // TODO: fix libxml2 wrapper
				return "";
			}
			private set {
			}
		}
		/**
		 * The notation name for this entity if it is
		 * unparsed. This is `null` if the entity is parsed.
		 */
		public string notation_name {
			get {
				// parsed: return null
				// unparsed: related notation's name // TODO
				// TODO: how does libxml2 associate notations with entities?
				// STUB
				return "";
			}
			private set {
			}
		}

		internal Entity (Xml.Entity *entity, Document doc) {
			base (NodeType.ENTITY, doc);

			this.entity = entity;
		}

		/* Public properties (Node-specific) */

		public override string node_name {
			get {
				// return this.entity->name; // TODO: breaking for some reason?
				return "";
			}
			internal set {
			}
		}


		public override DomNode? parent_node {
			get {
				return this.owner_document.doctype;
				// TODO: could this be differen tfrom this.entity->parent?
			}
			internal set {}
		}

		// node_value == null

		public override NodeList? child_nodes {
			owned get {
				// TODO: always create a new one?
				//       probably not a good idea; want to create one local one
				return new EntityChildNodeList (this.entity, this.owner_document);
			}
			internal set {
			}
		}

		/* Public methods (Node-specific) */
		public override DomNode? insert_before (DomNode new_child, DomNode? ref_child) throws DomError {
			return this.child_nodes.insert_before (new_child, ref_child);
		}
		public override DomNode? replace_child (DomNode new_child, DomNode old_child) throws DomError {
			return this.child_nodes.replace_child (new_child, old_child);
		}
		public override DomNode? remove_child (DomNode old_child) throws DomError {
			return this.child_nodes.remove_child (old_child);
		}
		public override DomNode? append_child (DomNode new_child) throws DomError {
			return this.child_nodes.append_child (new_child);
		}
		public override bool has_child_nodes () {
			return (this.child_nodes.length > 0);
		}
		public override DomNode? clone_nodes (bool deep) {
			return this; // STUB
		}

	}
}
