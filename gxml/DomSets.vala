/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 2 -*- */
/*
 *
 * Copyright (C) 2016  Daniel Espinosa <esodan@gmail.com>
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
 *      Daniel Espinosa <esodan@gmail.com>
 */

using Gee;

public interface GXml.DomTokenList : GLib.Object, Gee.BidirList<string> {
  public abstract ulong   length   { get; }
  public abstract string? item     (ulong index);
  public abstract bool    contains (string token);
  public abstract void    add      (string[] tokens);
  public abstract void    remove   (string[] tokens);
  /**
   * If @auto is true, adds @token if not present and removing if it, no @force value
   * is taken in account. If @auto is false, then @force is considered; if true adds
   * @token, if false removes it.
   */
  public abstract bool    toggle   (string token, bool force = false, bool auto = true);
  public abstract string  to_string ();
}

public interface GXml.DomSettableTokenList : GXml.DomTokenList {
  public abstract string @value { get; set; }
}
