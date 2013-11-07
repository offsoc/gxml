/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
/* Serialization.vala
 *
 * Copyright (C) 2012-2013  Richard Schwarting <aquarichy@gmail.com>
 * Copyright (C) 2013  Daniel Espinosa <esodan@gmail.com>
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *       Richard Schwarting <aquarichy@gmail.com>
 *       Daniel Espinosa <esodan@gmail.com>
 */

/**
 * Serializes and deserializes {@link GLib.Object}s to and from
 * {@link GXml.Node}.
 *
 * Serialization can automatically serialize a variety of public
 * properties.  {@link GLib.Object}s can also implement the
 * {@link GXml.Serializable} to partially or completely manage
 * serialization themselves, including non-public properties or
 * data types not automatically supported by {@link GXml.Serialization}.
 */
public class GXml.SerializableJson : GLib.Object, Serializable
{
	/* Serializable Interface properties */
	protected ParamSpec[] properties { get; set; }
	public bool serializable_property_use_nick { get; set; }
	public HashTable<string,GLib.ParamSpec>  ignored_serializable_properties { get; protected set; }
	public HashTable<string,GXml.Node>    unknown_serializable_property { get; protected set; }

	public string serializable_node_name () { return ""; }
	public string?  serialized_xml_node_value { get; protected set; default = null; }

	public virtual GLib.ParamSpec? find_property_spec (string property_name)
	{
		return default_find_property_spec (property_name);
	}

	public virtual void init_properties ()
	{
		default_init_properties ();
	}

	public virtual GLib.ParamSpec[] list_serializable_properties ()
	{
		return default_list_serializable_properties ();
	}

	public virtual void get_property_value (GLib.ParamSpec spec, ref Value val)
	{
		default_get_property_value (spec, ref val);
	}

	public virtual void set_property_value (GLib.ParamSpec spec, GLib.Value val)
	{
		default_set_property_value (spec, val);
	}

	public virtual bool transform_from_string (string str, ref GLib.Value dest)
	{
		return false;
	}

	public virtual bool transform_to_string (GLib.Value val, ref string str)
	{
		return false;
	}
  /**
   * If @node is a Document serialize just add an <Object> element.
   *
   * If @node is an Element serialize add to it an <Object> element.
   *
   * Is up to you to add convenient Element node to a Document, in order to be
   * used by serialize and add new <Object> tags per object to serialize.
   */
	public Node? serialize (Node node) throws GLib.Error
	{
		Document doc;
		Element root;
		ParamSpec[] props;
		string oid = "%p".printf(this);

		if (node is Document)
			doc = (Document) node;
		else
			doc = node.owner_document;

		root = doc.create_element ("Object");
		doc.append_child (root);
		root.set_attribute ("otype", this.get_type ().name ());
		root.set_attribute ("oid", oid);
		props = list_serializable_properties ();
		foreach (ParamSpec prop_spec in props) {
			serialize_property (root, prop_spec);
		}
		return root;
	}

	public virtual GXml.Node? serialize_property (Element element, 
	                                      GLib.ParamSpec prop)
	                                      throws GLib.Error
	{
		Type type;
		Value val;
		Node value_node = null;
		Element prop_node;

		type = prop.value_type;

		if (type.is_a (typeof (Serializable))) {
			val = Value (type);
			this.get_property_value (prop, ref val);
			return ((Serializable) val.get_object ()).serialize (element);
		}

		var doc = element.owner_document;
		prop_node = doc.create_element ("Property");
		prop_node.set_attribute ("ptype", prop.value_type.name ());
		prop_node.set_attribute ("pname", prop.name);
		element.append_child (prop_node);

		if (type.is_enum ())
		{
			val = Value (typeof (int));
			this.get_property_value (prop, ref val);
			value_node = doc.create_text_node ("%d".printf (val.get_int ()));
			prop_node.append_child (value_node);
			return prop_node;
		} 
		else if (Value.type_transformable (type, typeof (string))) 
		{ // e.g. int, double, string, bool
//		GLib.message ("DEBUG: Transforming property  name '%s' of object '%s', using GLib defaults", prop.name, this.get_type ().name ());
			val = Value (type);
			Value t = Value (typeof (string));
			this.get_property_value (prop, ref val);
			val.transform (ref t);
			value_node = doc.create_text_node (t.get_string ());
			prop_node.append_child (value_node);
			return prop_node;
		}
		else if (type == typeof (GLib.Type)) {
			value_node = doc.create_text_node (type.name ());
			prop_node.append_child (value_node);
			return prop_node;
		}
		else if (type.is_a (typeof (GLib.Object))
		           && ! type.is_a (typeof (Gee.Collection)))
		{
			GLib.Object child_object;

			// TODO: this is going to get complicated
			val = Value (typeof (GLib.Object));
			this.get_property_value (prop, ref val);
			child_object = val.get_object ();
			Document value_doc = Serialization.serialize_object (child_object);
			value_node = doc.copy_node (value_doc.document_element);
			prop_node.append_child (value_node);
			return prop_node;
		}
		//GLib.message ("DEBUG: serialing unknown property type '%s' of object '%s'", prop.name, this.get_type ().name ());
		serialize_unknown_property_type (prop_node, prop, out value_node);
		return prop_node;
	}

	public Node? deserialize (Node node) throws GLib.Error
	{
		Element obj_elem;
		ParamSpec[] specs;

		if (node is Document) {
			obj_elem = node.owner_document.document_element;
		}
		else {
			obj_elem = (Element) node;
		}

		specs = this.list_serializable_properties ();

		foreach (Node child_node in obj_elem.child_nodes) {
			deserialize_property (child_node);
		}
		return obj_elem;
	}

	public virtual bool deserialize_property (GXml.Node property_node) throws GLib.Error
	{
		//GLib.message ("At SerializableJson.deserialize_property");
		if (property_node.node_name == "Property")
		{
			Element prop_elem;
			string pname;
			string ptype;
			Type type;
			Value val;
			ParamSpec spec;
			//string ptype;

			prop_elem = (Element)property_node;
			pname = prop_elem.get_attribute ("pname");
			ptype = prop_elem.get_attribute ("ptype");
			type = Type.from_name (ptype);
			// Check name and type for property
			spec = this.find_property_spec (pname);

			if (spec == null) {
				GLib.message ("Deserializing object of type '%s' claimed unknown property named '%s'\nXML [%s]", ptype, pname, property_node.to_string ());
				unknown_serializable_property.set (property_node.node_name, property_node);
			}
			else {
				if (spec.value_type.is_a (typeof(Serializable)))
				{
					Value vobj = Value (spec.value_type);
					this.get_property (pname, ref vobj);
					((Serializable) vobj).deserialize (property_node);
				}
				else {
					val = Value (type);
					if (transform_from_string (prop_elem.content, ref val)) {
						this.set_property_value (spec, val);
						return true;
					}
					else if (GLib.Value.type_transformable (type, typeof (string))) {
						Serializable.string_to_gvalue (prop_elem.content, ref val);
						this.set_property_value (spec, val);
						//GLib.message (@"Setting value to property $(spec.name)");
					}
					else if (type.is_a (typeof (GLib.Object))) 
					{
						GXml.Node prop_elem_child;
						Object property_object;

						prop_elem_child = prop_elem.first_child;

						property_object = Serialization.deserialize_object_from_node (prop_elem_child);
						val.set_object (property_object);
						return true;
					}
					else {
						deserialize_unknown_property_type (prop_elem, spec);
						return false;
					}
				}
			}
			return true;
		}
		return false;
	}
}