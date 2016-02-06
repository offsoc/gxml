/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 2 -*- */
/* Notation.vala
 *
 * Copyright (C) 2011-2013  Richard Schwarting <aquarichy@gmail.com>
 * Copyright (C) 2011-2015  Daniel Espinosa <esodan@gmail.com>
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
 * License along with this library; if not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *      Richard Schwarting <aquarichy@gmail.com>
 *      Daniel Espinosa <esodan@gmail.com>
 */

using GXml;

class GDocumentTest : GXmlTest {
	public static void add_tests () {
		Test.add_func ("/gxml/gdocument/construct_from_path_error", () => {
				GDocument doc;
				try {
				GLib.Test.message ("invalid file...");
					// file does not exist
					doc = new GDocument.from_path ("/tmp/asdfjlkansdlfjl");
					assert_not_reached ();
				} catch {}

				try {
					// file exists, but is not XML (it's a directory!)
					doc = new GDocument.from_path ("/tmp/");
					assert_not_reached ();
				} catch  {}
				try {
					doc = new GDocument.from_path ("test_invalid.xml");
					assert_not_reached ();
				} catch {}
			});
		Test.add_func ("/gxml/gdocument/construct_from_stream", () => {
				var fin = File.new_for_path (GXmlTestConfig.TEST_DIR + "/test.xml");
				assert (fin.query_exists ());
				try {
					var instream = fin.read (null);
					var doc = new GDocument.from_stream (instream);
					assert (doc != null);
					// TODO: CHECKS
				} catch (GLib.Error e) {
					GLib.message ("%s", e.message);
					assert_not_reached ();
				}
			});
		Test.add_func ("/gxml/gdocument/gfile/local", () => {
			try {
				var f = GLib.File.new_for_path (GXmlTestConfig.TEST_SAVE_DIR+"/tw-test-file.xml");
				if (f.query_exists ()) f.delete ();
				var s = new GLib.StringBuilder ();
				s.append ("""<root />""");
				var d = new GDocument.from_string (s.str);
				GLib.message ("Saving to file: "+f.get_uri ()+d.to_string ());
				d.save_as (f);
				assert (f.query_exists ());
				var d2 = new GDocument.from_file (f);
				assert (d2 != null);
				assert (d2.root != null);
				assert (d2.root.name == "root");
				f.delete ();
			} catch (GLib.Error e) {
				GLib.message ("Error: "+e.message);
				assert_not_reached ();
			}
			});
		Test.add_func ("/gxml/gdocument/gfile/remote", () => {
			try {
				var net = GLib.NetworkMonitor.get_default ();
				if (net.connectivity != GLib.NetworkConnectivity.FULL) return;
				var rf = GLib.File.new_for_uri ("https://git.gnome.org/browse/gxml/plain/gxml.doap");
				assert (rf.query_exists ());
				var d = new GDocument.from_file (rf);
				assert (d != null);
				assert (d.root != null);
				assert (d.root.name == "Project");
				bool fname, fshordesc, fdescription, fhomepage;
				fname = fshordesc = fdescription = fhomepage = false;
				foreach (GXml.Node n in d.root.childs) {
					if (n.name == "name") fname = true;
					if (n.name == "shortdesc") fshordesc = true;
					if (n.name == "description") fdescription = true;
					if (n.name == "homepage") fhomepage = true;
				}
				assert (fname);
				assert (fshordesc);
				assert (fdescription);
				assert (fhomepage);
				var f = GLib.File.new_for_path (GXmlTestConfig.TEST_SAVE_DIR+"/xml.doap");
				d.save_as (f);
				assert (f.query_exists ());
				f.delete ();
			} catch (GLib.Error e) {
				GLib.message ("Error: "+e.message);
				assert_not_reached ();
			}
		});
		Test.add_func ("/gxml/gdocument/construct_from_stream_error", () => {
				File fin;
				InputStream instream;
				FileIOStream iostream;
				GDocument doc;

				try {
					fin = File.new_tmp ("gxml.XXXXXX", out iostream);
					doc = new GDocument.from_stream (iostream.input_stream);
					GLib.message ("Passed parse error stream");
					assert_not_reached ();
				} catch  {}
			});
		Test.add_func ("/gxml/gdocument/construct_from_string", () => {
				string xml;
				GDocument doc;
				GXml.Node root;

				xml = "<Fruits><Apple></Apple><Orange></Orange></Fruits>";
				doc = new GDocument.from_string (xml);

				root = doc.root;
				assert (root.name == "Fruits");
				assert (root.children.size == 2);
				var n1 = root.children.get (0);
				assert (n1 != null);
				assert (n1.name == "Apple");
			});
		Test.add_func ("/gxml/gdocument/construct_from_string_no_root", () => {
			try {
				string xml;
				GDocument doc;
				GXml.Node root;

				xml = """<?xml version="1.0"?>""";
				doc = new GDocument.from_string (xml);
				assert_not_reached ();
			} catch {}
			});
		Test.add_func ("/gxml/gdocument/construct_from_string_invalid", () => {
			try {
				string xml;
				GDocument doc;
				GXml.Node root;

				xml = "";
				doc = new GDocument.from_string (xml);
			} catch {}
			});
		Test.add_func ("/gxml/gdocument/save", () => {
				GDocument doc;
				int exit_status;

				try {
					doc = new GDocument.from_string ("<root />");
					var f = GLib.File.new_for_path (GXmlTestConfig.TEST_SAVE_DIR+"/test_out_path.xml");
					doc.save_as (f);
					assert (f.query_exists ());
					f.delete ();
				} catch (GLib.Error e) {
					Test.message ("%s", e.message);
					assert_not_reached ();
				}
			});
		Test.add_func ("/gxml/gdocument/save_error", () => {
				GDocument doc;

				try {
					doc = new GDocument.from_string ("<root />");
					doc.save_as (GLib.File.new_for_path ("/tmp/a/b/c/d/e/f/g/h/i"));
					assert_not_reached ();
				} catch {}
			});

		Test.add_func ("/gxml/gdocument/create_element", () => {
				GDocument doc = new GDocument.from_string ("<root />");
				GElement elem = null;

				elem = (GElement) doc.create_element ("Banana");
				assert (elem.tag_name == "Banana");
				assert (elem.tag_name != "banana");

				elem = (GElement) doc.create_element ("ØÏØÏØ¯ÏØÏ  ²øœ³¤ïØ£");
			});
		Test.add_func ("/gxml/gdocument/create_text_node", () => {
				GDocument doc = new GDocument.from_string ("<root />");
				Text text = (Text) doc.create_text ("Star of my dreams");

				assert (text.name == "#text");
				assert (text.value == "Star of my dreams");
			});
		Test.add_func ("/gxml/gdocument/create_comment", () => {
				GDocument doc = new GDocument.from_string ("<root />");
				Comment comment = (GXml.Comment) doc.create_comment ("Ever since the day we promised.");

				assert (comment.name == "#comment");
				assert (comment.str == "Ever since the day we promised.");
			});
		Test.add_func ("/gxml/gdocument/create_cdata_section", () => {
				GDocument doc = new GDocument.from_string ("<root />");
				CDATA cdata = (CDATA) doc.create_cdata ("put in real cdata");

				assert (cdata.name == "#cdata-section");
				assert (cdata.value == "put in real cdata");
			});
		Test.add_func ("/gxml/gdocument/create_processing_instruction", () => {
				GDocument doc = new GDocument.from_string ("<root />");
				ProcessingInstruction instruction = (ProcessingInstruction) doc.create_pi ("target", "data");

				assert (instruction.name == "target");
				assert (instruction.target == "target");
				assert (instruction.data == "data");
				assert (instruction.value == "data");
			});
		Test.add_func ("/gxml/gdocument/create_attribute", () => {
				GDocument doc = new GDocument.from_string ("<root />");
				((GElement) doc.root).set_attr ("attrname", "attrvalue");
				Test.message ("DOC:"+doc.to_string ());
				var attr = ((GElement) doc.root).get_attr ("attrname");
				Test.message ("Attr name: "+attr.name);
				Test.message ("Attr value: "+attr.value);
				assert (attr != null);
				assert (attr is GAttribute);
				assert (attr.name == "attrname");
				assert (attr.value == "attrvalue");
				//
				//Test.message ("DOC libxml2:"+doc.libxml_to_string ());
			});/*
		Test.add_func ("/gxml/gdocument/to_string", () => {
				GDocument doc = new GDocument.from_string ("<root />");
				assert (doc.to_string () == "<?xml version=\"1.0\"?>
<Sentences>
  <Sentence lang=\"en\">I like the colour blue.</Sentence>
  <Sentence lang=\"de\">Ich liebe die T&#xFC;r.</Sentence>
  <Authors>
    <Author>
      <Name>Fred</Name>
      <Email>fweasley@hogwarts.co.uk</Email>
    </Author>
    <Author>
      <Name>George</Name>
      <Email>gweasley@hogwarts.co.uk</Email>
    </Author>
  </Authors>
</Sentences>
");
				// TODO: want to test with format on and off

			});*/
	}
}