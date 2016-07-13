/* GXmlComment.vala
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

/**
 * Class implemeting {@link GXml.Comment} interface, not tied to libxml-2.0 library.
 */
public class GXml.GComment : GXml.GNode, GXml.Comment, GXml.DomCharacterData, GXml.DomComment
{
  public GComment (GDocument doc, Xml.Node *node)
  {
    _node = node;
    _doc = doc;
  }
  public override string name {
    owned get {
      return "#comment".dup ();
    }
  }
  // GXml.Comment
  public string str { owned get { return base.value; } }
  // GXml.DomCharacterData
  public string data {
    get {
      return str;
    }
    set {
      str = value;
    }
  }
}
