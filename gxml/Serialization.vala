/*
 * Copyright (C) 2012 Richard Schwarting
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
 */

/* TODO: so it seems we can get property information from GObjectClass
   but that's about it.  Need to definitely use introspection for anything
   tastier */
/* TODO: document memory management for the C side */

using GXml;

namespace GXml {
	/**
	 * Errors from {@link Serialization}.
	 */
	public errordomain SerializationError {
		/**
		 * An object without a known {@link GLib.Type} was encountered.
		 */
		UNKNOWN_TYPE,
		/**
		 * A property was described in XML that is not known to the object's type.
		 */
		UNKNOWN_PROPERTY,
		/**
		 * An object with a known {@link GLib.Type} that we do not support was encountered.
		 */
		UNSUPPORTED_TYPE
	}

	/**
	 * Serializes and deserializes {@link GLib.Object}s to and from
	 * {@link GXml.DomNode}.
	 *
	 * Serialization can automatically serialize a variety of public
	 * properties.  {@link GLib.Object}s can also implement the
	 * {@link GXml.Serializable} to partially or completely manage
	 * serialization themselves, including non-public properties or
	 * data types not automatically supported by {@link GXml.Serialization}.
	 */
	public class Serialization : GLib.Object {
		private static void print_debug (GXml.Document doc, GLib.Object object) {
			stdout.printf ("Object XML\n---\n%s\n", doc.to_string ());

			stdout.printf ("object\n---\n");
			stdout.printf ("get_type (): %s\n", object.get_type ().name ());
			stdout.printf ("get_class ().get_type (): %s\n", object.get_class ().get_type ().name ());

			ParamSpec[] properties;
			properties = object.get_class ().list_properties ();
			stdout.printf ("object has %d properties\n", properties.length);
			foreach (ParamSpec prop_spec in properties) {
				stdout.printf ("---\n");
				stdout.printf ("name: %s\n", prop_spec.name);
				stdout.printf ("value_type: %s\n", prop_spec.value_type.name ());
				stdout.printf ("owner_type: %s\n", prop_spec.owner_type.name ());
				stdout.printf ("get_name (): %s\n", prop_spec.get_name ());
				stdout.printf ("get_blurb (): %s\n", prop_spec.get_blurb ());
				stdout.printf ("get_nick (): %s\n", prop_spec.get_nick ());
			}
		}

		/*
		 * This coordinates the automatic serialization of individual
		 * properties.  As of 0.2, it supports enums, anything that
		 * {@link GLib.Value} can transform into a string, and
		 * operates recursively.
		 */
		private static GXml.DomNode serialize_property (GLib.Object object, ParamSpec prop_spec, GXml.Document doc) throws SerializationError, DomError {
			Type type;
			Value value;
			DomNode value_node;
			Serializable serializable = null;

			if (object.get_type ().is_a (typeof (Serializable))) {
				serializable = (Serializable)object;
			}

			type = prop_spec.value_type;

			if (prop_spec.value_type.is_enum ()) {
				/* We're going to handle this simply by saving it
				   as an int.  If we save a string representation,
				   we can't easily convert it back to the number
				   in a generic fashion unless we can use GEnumClass,
				   but I can't figure out how to get that right now,
				   except from a GParamSpecEnum, but I don't know
				   how to get that, at least in Vala (e.g. is it
				   supposed to be as simple in C as casting the
				   GParamSpec for an enum to GParamSpecEnum (assuming
				   it truly is the latter, but is returned as the
				   former by list_properties) */
				value = Value (typeof (int));
				if (serializable != null) {
					serializable.get_property (prop_spec, ref value);
				} else {
					object.get_property (prop_spec.name, ref value);
				}
				value_node = doc.create_text_node ("%d".printf (value.get_int ()));
				/* TODO: in the future, perhaps figure out GEnumClass
				   and save it as the human readable enum value :D */
			} else if (Value.type_transformable (prop_spec.value_type, typeof (string))) { // e.g. int, double, string, bool
				value = Value (typeof (string));
				if (serializable != null) {
					serializable.get_property (prop_spec, ref value);
				} else {
					object.get_property (prop_spec.name, ref value);
				}
				value_node = doc.create_text_node (value.get_string ());
			} else if (type == typeof (GLib.Type)) {
				value_node = doc.create_text_node (type.name ());
				// } else if (type == typeof (GLib.HashTable)) {
				// } else if (type == typeof (Gee.List)) { // TODO: can we do a catch all for Gee.Collection and have <Collection /> ?
				// } else if (type.is_a (typeof (Gee.Collection))) {
			} else if (type.is_a (typeof (GLib.Object))) {
				// TODO: this is going to get complicated
				value = Value (typeof (GLib.Object));
				if (serializable != null) {
					serializable.get_property (prop_spec, ref value);
				} else {
					object.get_property (prop_spec.name, ref value);
				}
				GLib.Object child_object = value.get_object ();
				value_node = Serialization.serialize_object (child_object); // catch serialisation errors?
				// TODO: caller will append_child; can we cross documents like this?  Probably not :D want to be able to steal?, attributes seem to get lost
			} else {
				throw new SerializationError.UNSUPPORTED_TYPE ("Can't currently serialize type '%s' for property '%s' of object '%s'", type.name (), prop_spec.name, object.get_type ().name ());
			}

			return value_node;
		}

		/**
		 * Serializes a {@link GLib.Object} into a {@link GXml.DomNode}.
		 *
		 * This takes a {@link GLib.Object} and serializes it into a
		 * {@link GXml.DomNode} which can be saved to disk or
		 * transferred over a network.  It handles serialization of
		 * primitive properties and some more complex ones like enums,
		 * other {@link GLib.Object}s recursively, and some collections.
		 *
		 * The serialization process can be customised for an object
		 * by having the object implement the {@link GXml.Serializable}
		 * interface, which allows direct control over the
		 * conversation of individual properties into {@link GXml.DomNode}s
		 * and the object's list of properties as used by
		 * {@link GXml.Serialization}.
		 *
		 * A {@link GXml.SerializationError} may be thrown if there is
		 * a problem serializing a property (e.g. the type is unknown,
		 * unsupported, or the property isn't known to the object).
		 *
		 * @param object A {@link GLib.Object} to serialize
		 * @return a {@link GXml.DomNode} representing the serialized `object`
		 */
		public static GXml.DomNode serialize_object (GLib.Object object) throws SerializationError {
			Document doc;
			Element root;
			ParamSpec[] prop_specs;
			Element prop;
			Serializable serializable = null;
			DomNode value_prop = null;

			if (object.get_type ().is_a (typeof (Serializable))) {
				serializable = (Serializable)object;
			}

			/* Create an XML Document to return the object
			   in.  TODO: consider just returning an
			   <Object> node; but then we'd probably want
			   a separate document for it to already be a
			   part of as its owner_document. */
			try {
				doc = new Document ();
				root = doc.create_element ("Object");
				doc.append_child (root);
				root.set_attribute ("otype", object.get_type ().name ());
				root.set_attribute ("oid", "%p".printf (object));

				/* TODO: make sure we don't use an out param for our returned list
				   size in our interface's list_properties (), using
				   [CCode (array_length_type = "guint")] */
				if (serializable != null) {
					prop_specs = serializable.list_properties ();
				} else {
					prop_specs = object.get_class ().list_properties ();
				}

				/* Exam the properties of the object and store
				   them with their name, type and value in XML
				   Elements.  Use GValue to convert them to
				   strings. (Too bad deserialising isn't that
				   easy w.r.t. string conversion.) */
				foreach (ParamSpec prop_spec in prop_specs) {
					prop = doc.create_element ("Property");
					prop.set_attribute ("ptype", prop_spec.value_type.name ());
					prop.set_attribute ("pname", prop_spec.name);

					value_prop = null;
					if (serializable != null) {
						value_prop = serializable.serialize_property (prop_spec.name, prop_spec, doc);
					}
					if (value_prop == null) {
						value_prop = Serialization.serialize_property (object, prop_spec, doc);
					}

					prop.append_child (value_prop);
					root.append_child (prop);
				}
			} catch (GXml.DomError e) {
				GLib.error ("%s", e.message);
				// TODO: handle this better
			}

			/* Debug output */
			bool debug = false;
			if (debug) {
				Serialization.print_debug (doc, object);
			}

			return doc.document_element; // user can get Document through .owner_document
		}

		/*
		 * This handles deserializing properties individually.
		 * Because {@link GLib.Value} doesn't handle transforming
		 * strings back to other types, we use our own function to do
		 * that.
		 */
		private static void deserialize_property (ParamSpec spec, Element prop_elem, out Value val) throws SerializationError {
			Type type;

			type = spec.value_type;

			// if (false || ptype != "") {
			// 	// TODO: undisable if we support fields at some point
			// 	type = Type.from_name (ptype);
			// 	if (type == 0) {
			// 		/* This probably shouldn't happen while we're using
			// 		   ParamSpecs but if we support non-property fields
			// 		   later, it might be necessary again :D */
			// 		throw new SerializationError.UNKNOWN_TYPE ("Deserializing object '%s' has property '%s' with unknown type '%s'", otype, pname, ptype);
			// 	}
			// }

			// Get value and save this all as a parameter
			bool transformed = false;
			val = Value (type);
			if (GLib.Value.type_transformable (type, typeof (string))) {
				try {
					string_to_gvalue (prop_elem.content, ref val);
					transformed = true;
				} catch (SerializationError e) {
					throw new SerializationError.UNSUPPORTED_TYPE ("string_to_gvalue should transform it but failed");
				}
			// } else if (type.is_a (typeof (Gee.Collection))) {
			} else if (type.is_a (typeof (GLib.Object))) {
				GXml.DomNode prop_elem_child;
				Object property_object;

				try {
					prop_elem_child = prop_elem.first_child;
					property_object = Serialization.deserialize_object (prop_elem_child);
					val.set_object (property_object);
					transformed = true;
				} catch (GXml.SerializationError e) {
					// We don't want this one caught by deserialize_object, or we'd have a cascading error message.  Hmm, not so bad if it does, though.
					e.message += "\nXML [%s]".printf (prop_elem.to_string ());
					throw e;
				}
			}

			if (transformed == false) {
				throw new SerializationError.UNSUPPORTED_TYPE ("Failed to transform property from string to type.");
			}
		}

		/*
		 * This table is used while deserializing objects to avoid
		 * creating duplicate objects when we encounter multiple
		 * references to a single serialized object.
		 *
		 * TODO: one problem, if you deserialize two XML structures,
		 * some differing objects might have the same OID :( Need to
		 * find make it more unique than just the memory address. */
		private static HashTable<string,Object> cache = null;

		public static void clear_cache () {
			if (Serialization.cache != null)
				Serialization.cache.remove_all ();
		}

		/**
		 * Deserialize a {@link GXml.DomNode} back into a {@link GLib.Object}.
		 *
		 * This deserializes a {@link GXml.DomNode} back into a {@link GLib.Object}.  The
		 * {@link GXml.DomNode} must represented a {@link GLib.Object} as serialized by
		 * {@link GXml.Serialization}.  The types of the objects that are
		 * being deserialized must be known to the system
		 * deserializing them or a {@link GXml.SerializationError} will
		 * result.
		 *
		 * @param node {@link GXml.DomNode} representing a {@link GLib.Object}
		 * @return the deserialized {@link GLib.Object}
		 */
		public static GLib.Object deserialize_object (DomNode node) throws SerializationError {
			Element obj_elem;

			string otype;
			string oid;
			Type type;
			Object obj;
			unowned ObjectClass obj_class;
			ParamSpec[] specs;
			bool property_found;
			Serializable serializable = null;

			obj_elem = (Element)node;

			oid = obj_elem.get_attribute ("oid");

			if (Serialization.cache == null) {
				Serialization.cache = new HashTable<string,Object> (str_hash, str_equal);
			}
			if (oid != "" && Serialization.cache.contains (oid)) {
				return Serialization.cache.get (oid);
			}

			// Get the object's type
			// TODO: wish there was a g_object_class_from_name () method
			otype = obj_elem.get_attribute ("otype");
			type = Type.from_name (otype);
			if (type == 0) {
				throw new SerializationError.UNKNOWN_TYPE ("Deserializing object claims unknown type '%s'", otype);
			}

			// Get the list of properties as ParamSpecs
			obj = Object.newv (type, new Parameter[] {}); // TODO: causes problems with Enums when 0 isn't a valid enum value (e.g. starts from 2 or something)
			obj_class = obj.get_class ();

			if (type.is_a (typeof (Serializable))) {
				serializable = (Serializable)obj;
			}

			if (serializable != null) {
				specs = serializable.list_properties ();
			} else {
				specs = obj_class.list_properties ();
			}

			foreach (DomNode child_node in obj_elem.child_nodes) {
				if (child_node.node_name == "Property") {
					Element prop_elem;
					string pname;
					Value val;
					//string ptype;

					prop_elem = (Element)child_node;
					pname = prop_elem.get_attribute ("pname");
					//ptype = prop_elem.get_attribute ("ptype"); // optional

					// Check name and type for property
					ParamSpec? spec = null;
					if (serializable != null) {
						spec = serializable.find_property (pname);
					} else {
						spec = obj_class.find_property (pname);
					}

					if (spec == null) {
						throw new SerializationError.UNKNOWN_PROPERTY ("Deserializing object of type '%s' claimed unknown property named '%s'\nXML [%s]", otype, pname, obj_elem.to_string ());
					}

					try {
						bool serialized = false;

						if (serializable != null) {
							serialized = serializable.deserialize_property (spec.name, /* out val, */ spec, prop_elem); // TODO: consider rearranging these or the ones in Serializer to match
						}
						if (!serialized) {
							Serialization.deserialize_property (spec, prop_elem, out val);
							if (serializable != null) {
								serializable.set_property (spec, val);
							} else {
								obj.set_property (pname, val);
							}
							// TODO: should we make a note that for implementing {get,set}_property in the interface, they should specify override (in Vala)?  What about in C?  Need to test which one gets called in which situations (yeah, already read the tutorial)
						}
					} catch (SerializationError.UNSUPPORTED_TYPE e) {
						throw new SerializationError.UNSUPPORTED_TYPE ("Cannot deserialize object '%s's property '%s' with type '%s/%s': %s\nXML [%s]",
											       otype, spec.name, spec.value_type.name (), spec.value_type.to_string (), e.message, obj_elem.to_string ());
					}
				}
			}

			// Set it as the last possible action, so that invalid objects won't end up getting stored
			Serialization.cache.set (oid, obj);

			return obj;
		}

		/* TODO:
		 * - can't seem to pass delegates on struct methods to another function :(
		 * - no easy string_to_gvalue method in GValue :(
		 */

		/**
		 * Transforms a string into another type hosted by {@link GLib.Value}.
		 *
		 * A utility function that handles converting a string
		 * representation of a value into the type specified by the
		 * supplied #GValue dest.  A #GXmlSerializationError will be
		 * set if the string cannot be parsed into the desired type.
		 *
		 * @param str the string to transform into the given #GValue object
		 * @param dest the #GValue out parameter that will contain the parsed value from the string
		 * @return `true` if parsing succeeded, otherwise `false`
		 */
		/*
		 * @todo: what do functions written in Vala return in C when
		 * they throw an exception?  NULL/0/FALSE?
		 */
		public static bool string_to_gvalue (string str, ref GLib.Value dest) throws SerializationError {
			Type t = dest.type ();
			GLib.Value dest2 = Value (t);
			bool ret = false;

			if (t == typeof (int64)) {
				int64 val;
				if (ret = int64.try_parse (str, out val)) {
					dest2.set_int64 (val);
				}
			} else if (t == typeof (int)) {
				int64 val;
				if (ret = int64.try_parse (str, out val)) {
					dest2.set_int ((int)val);
				}
			} else if (t == typeof (long)) {
				int64 val;
				if (ret = int64.try_parse (str, out val)) {
					dest2.set_long ((long)val);
				}
			} else if (t == typeof (uint)) {
				uint64 val;
				if (ret = uint64.try_parse (str, out val)) {
					dest2.set_uint ((uint)val);
				}
			} else if (t == typeof (ulong)) {
				uint64 val;
				if (ret = uint64.try_parse (str, out val)) {
					dest2.set_ulong ((ulong)val);
				}
			} else if ((int)t == 20) { // gboolean
				bool val = (str == "TRUE");
				dest2.set_boolean (val); // TODO: huh, investigate why the type is gboolean and not bool coming out but is going in
				ret = true;
			} else if (t == typeof (bool)) {
				bool val;
				if (ret = bool.try_parse (str, out val)) {
					dest2.set_boolean (val);
				}
			} else if (t == typeof (float)) {
				double val;
				if (ret = double.try_parse (str, out val)) {
					dest2.set_float ((float)val);
				}
			} else if (t == typeof (double)) {
				double val;
				if (ret = double.try_parse (str, out val)) {
					dest2.set_double (val);
				}
			} else if (t == typeof (string)) {
				dest2.set_string (str);
				ret = true;
			} else if (t == typeof (char)) {
				int64 val;
				if (ret = int64.try_parse (str, out val)) {
					dest2.set_char ((char)val);
				}
			} else if (t == typeof (uchar)) {
				int64 val;
				if (ret = int64.try_parse (str, out val)) {
					dest2.set_uchar ((uchar)val);
				}
			} else if (t == Type.BOXED) {
			} else if (t.is_enum ()) {
				int64 val;
				if (ret = int64.try_parse (str, out val)) {
					dest2.set_enum ((int)val);
				}
			} else if (t.is_flags ()) {
			} else if (t.is_object ()) {
			} else {
			}

			if (ret == true) {
				dest = dest2;
				return true;
			} else {
				throw new SerializationError.UNSUPPORTED_TYPE ("%s/%s", t.name (), t.to_string ());
			}
		}
	}
}	