# inspired by folks' documentation Makefile.am

# distclean_dirs? 
# phony_deps?
distclean_dirs = \
	gxml \
	gtk-doc \
	$(NULL)

phony_deps = \
	gxml-doc \
	gxml-gtk-doc \
	$(NULL)

gxml_wiki_pages = \
	concepts \
	glossary \
	debugging \
	$(NULL)

# Huh, gxml_wiki_files isn't defined for a while down below
EXTRA_DIST = $(gxml_wiki_files)



# ---------------------------------------------------------

gxmldocdir=$(datadir)/devhelp/references/gxml
gxmlimgdir=$(datadir)/devhelp/references/gxml/img

gxmlgtkdocdir=$(datadir)/gtk-doc/html/gxml

common_doc_files = \
	*.css \
	*.png \
	*.js \
	index.htm \
	*.html \
	$(NULL)

gxmldoc_DATA = \
	gxml/gxml/gxml.devhelp2 \
	$(addprefix gxml/gxml/,$(common_doc_files)) \
	$(NULL)

gxmlgtkdoc_DATA = gtk-doc/gxml/html/*

# gxmlimg_DATA = gxml/gxml/img/*.png

# $(gxmldoc_DATA) ($gxmlimg_DATA): gxml-doc
$(gxmldoc_DATA): gxml-doc
$(gxmlgtkdoc_DATA): gxml-gtk-doc


# -------------------------------------------------------

valadoc_flags = \
	--force \
	--package-version $(PACKAGE_VERSION) \
	$(NULL)

#	$(top_srcdir)/gxml/internal.vala 
gxml_doc_files_blacklist = \
	$(NULL)

# this expands the list of files, so we can filter out elements
gxml_doc_files_all = \
	$(wildcard $(top_srcdir)/gxml/*.vala) \
	$(NULL)

gxml_wiki_files = \
	$(addprefix wiki/,$(addsuffix .valadoc,$(gxml_wiki_pages))) \
	$(NULL)

# TODO: Fix this.  Sorting done to "work around the native doclet portino of bgo#662784" - folks
gxml_doc_files = \
	$(sort \
	$(filter-out $(gxml_doc_files_blacklist),$(gxml_doc_files_all)))

# todo: find out what dependencies I want/need to set
gxml_doc_deps = \
	gio-2.0 \
	gee-0.8 \
	libxml-2.0 \
	$(NULL)

valadoc_flags_gxml = \
	$(valadoc_flags) \
	-X $(top_srcdir)/gxml/gxml.h \
	$(addprefix --pkg=,$(gxml_doc_deps)) \
	--vapidir=$(top_srcdir)/gxml \
	--vapidir=$(top_srcdir)/vapi \
	--wiki=$(top_srcdir)/docs/wiki \
	$(gxml_doc_files) \
	$(NULL)


#	$(AM_V_GEN)$(VALADOC) 
gxml-doc: $(gxml_doc_files) $(gxml_wiki_files)
	$(VALADOC) \
		-o gxml/ \
		--doclet=devhelp \
		$(valadoc_flags_gxml) \
		$(NULL)

# TODO: need to figure out how to not rely on -0.2 in this Makefile.am
# AM_V_GEN: what does it do?  It appears to prettify output but also obscure errors :D
#	$(AM_V_GEN)$(VALADOC)
gxml-gtk-doc: $(gxml_doc_files) $(gxml_wiki_files)
	$(VALADOC) \
		-X -l -X $(top_builddir)/gxml/.libs/libgxml-0.2.so \
		-o gtk-doc/gxml \
		--doclet=gtkdoc \
		$(valadoc_flags_gxml) \
		$(NULL)

.PHONY: $(phony_deps)

distclean:
	rm -rf $(distclean_dirs) Makefile

# Hack, because I don't know how to make the other ones targets :D
# all: gxml-gtk-doc gxml-doc

-include $(top_srcdir)/git.mk
