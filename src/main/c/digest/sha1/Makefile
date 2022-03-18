
SHELL = /bin/sh

# V=0 quiet, V=1 verbose.  other values don't work.
V = 0
Q1 = $(V:1=)
Q = $(Q1:0=@)
ECHO1 = $(V:1=@ :)
ECHO = $(ECHO1:0=@ echo)
NULLCMD = :

#### Start of system configuration section. ####
top_srcdir = /home/duncan/work/graal/truffleruby/lib/cext/include/stubs
srcdir = .
topdir = .
hdrdir = /home/duncan/work/graal/truffleruby/lib/cext/include
arch_hdrdir = /home/duncan/work/graal/truffleruby/lib/cext/include
PATH_SEPARATOR = :
VPATH = $(srcdir):$(arch_hdrdir)/ruby:$(hdrdir)/ruby
RUBYLIB =
RUBYOPT = -
prefix = $(DESTDIR)/home/duncan/work/graal/truffleruby
exec_prefix = $(prefix)
rubylibprefix = $(libdir)/$(RUBY_BASE_NAME)
includedir = $(DESTDIR)/home/duncan/work/graal/truffleruby/lib/cext
rubyarchhdrdir = $(DESTDIR)/home/duncan/work/graal/truffleruby/lib/cext/include
rubyhdrdir = $(DESTDIR)/home/duncan/work/graal/truffleruby/lib/cext/include
sysconfdir = $(DESTDIR)/home/duncan/work/graal/truffleruby/etc
bindir = $(exec_prefix)/bin
libdir = $(exec_prefix)/lib
rubylibdir = $(libdir)/mri
rubyarchdir = $(rubylibdir)
archdir = $(rubyarchdir)
sitedir = $(rubylibprefix)/site_ruby
sitehdrdir = $(rubyhdrdir)/site_ruby
sitelibdir = $(sitedir)/$(ruby_version)
sitearchdir = $(sitelibdir)/$(sitearch)
datarootdir = $(prefix)/share
datadir = $(datarootdir)
mandir = $(datarootdir)/man
ridir = $(datarootdir)/ri
vendordir = $(rubylibprefix)/vendor_ruby


CC_WRAPPER = 
CC = /home/duncan/work/graal/graal/sulong/mxbuild/linux-amd64/SULONG_BOOTSTRAP_TOOLCHAIN/bin/graalvm-native-clang
CXX = /home/duncan/work/graal/graal/sulong/mxbuild/linux-amd64/SULONG_BOOTSTRAP_TOOLCHAIN/bin/graalvm-native-clang++
LIBRUBY = cext/libtruffleruby.so
LIBRUBY_A = 
LIBRUBYARG_SHARED = -lgraalvm-llvm
LIBRUBYARG_STATIC = 
empty =
OUTFLAG = -o $(empty)
COUTFLAG = -o $(empty)
CSRCFLAG = $(empty)

RUBY_EXTCONF_H = extconf.h
cflags   = $(optflags) $(debugflags) $(warnflags)
cxxflags = $(optflags) $(debugflags) $(warnflags)
optflags = 
debugflags = 
warnflags = -Werror=implicit-function-declaration -Wno-int-conversion -Wno-int-to-pointer-cast -Wno-incompatible-pointer-types -Wno-format-invalid-specifier -Wno-format-extra-args -ferror-limit=500 -Wundef -Werror
cppflags =  -fdebug-prefix-map=/home/duncan/work/graal/truffleruby=.
CCDLFLAGS = -fPIC
CFLAGS   = $(CCDLFLAGS) $(cflags) $(ARCH_FLAG)
INCFLAGS = -I. -I$(arch_hdrdir) -I$(hdrdir) -I$(srcdir)
DEFS     = -DTRUFFLERUBY_ABI_VERSION=3.0.3.7
CPPFLAGS = -DRUBY_EXTCONF_H=\"$(RUBY_EXTCONF_H)\"  $(DEFS) $(cppflags)
CXXFLAGS = $(CCDLFLAGS) $(cxxflags) $(ARCH_FLAG)
ldflags  = 
dldflags =  
ARCH_FLAG = 
DLDFLAGS = $(ldflags) $(dldflags) $(ARCH_FLAG)
LDSHARED = $(CC) -shared
LDSHAREDXX = $(CXX) -shared
AR = /home/duncan/work/graal/graal/sulong/mxbuild/linux-amd64/SULONG_BOOTSTRAP_TOOLCHAIN/bin/ar
EXEEXT = 

RUBY_BASE_NAME = ruby
RUBY_INSTALL_NAME = truffleruby
RUBYW_INSTALL_NAME = 
RUBY_SO_NAME = ruby

arch = x86_64-linux
sitearch = $(arch)
ruby_version = 3.0.3.7
ruby = /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby
RUBY = $(ruby)
ruby_headers = $(hdrdir)/ruby.h $(hdrdir)/ruby/backward.h $(hdrdir)/ruby/ruby.h $(hdrdir)/ruby/defines.h $(hdrdir)/ruby/missing.h $(hdrdir)/ruby/intern.h $(hdrdir)/ruby/st.h $(hdrdir)/ruby/subst.h $(arch_hdrdir)/ruby/config.h $(RUBY_EXTCONF_H)

RM = rm -f
RM_RF = $(RUBY) -run -e rm -- -rf
RMDIRS = rmdir --ignore-fail-on-non-empty -p
MAKEDIRS = mkdir -p
INSTALL = /usr/bin/install -c
INSTALL_PROG = $(INSTALL) -m 0755
INSTALL_DATA = $(INSTALL) -m 0644
COPY = cp
TOUCH = exit >

#### End of system configuration section. ####

preload = digest
libpath = .
LIBPATH =  -L.
DEFFILE = 

CLEANFILES = mkmf.log
DISTCLEANFILES = 
DISTCLEANDIRS = 

extout = 
extout_prefix = 
target_prefix = /digest
LOCAL_LIBS = 
LIBS = -lgraalvm-llvm   
ORIG_SRCS = sha1.c sha1init.c
SRCS = $(ORIG_SRCS) sha1init.c sha1.c
OBJS = sha1init.o sha1.o
HDRS = $(srcdir)/extconf.h $(srcdir)/sha1.h $(srcdir)/sha1cc.h
LOCAL_HDRS = 
TARGET = sha1
TARGET_NAME = sha1
TARGET_ENTRY = Init_$(TARGET_NAME)
DLLIB = $(TARGET).so
EXTSTATIC = 
STATIC_LIB = 

TIMESTAMP_DIR = .
BINDIR        = $(bindir)
RUBYCOMMONDIR = $(rubylibdir)
RUBYLIBDIR    = $(rubylibdir)$(target_prefix)
RUBYARCHDIR   = $(archdir)$(target_prefix)
HDRDIR        = $(rubyhdrdir)/ruby$(target_prefix)
ARCHHDRDIR    = $(rubyhdrdir)/$(arch)/ruby$(target_prefix)
TARGET_SO_DIR =
TARGET_SO     = $(TARGET_SO_DIR)$(DLLIB)
CLEANLIBS     = $(TARGET_SO) 
CLEANOBJS     = *.o  *.bak

all:    $(DLLIB)
static: all
.PHONY: all install static install-so install-rb
.PHONY: clean clean-so clean-static clean-rb

clean-static::
clean-rb-default::
clean-rb::
clean-so::
clean: clean-so clean-static clean-rb-default clean-rb
		-$(Q)$(RM) $(CLEANLIBS) $(CLEANOBJS) $(CLEANFILES) .*.time

distclean-rb-default::
distclean-rb::
distclean-so::
distclean-static::
distclean: clean distclean-so distclean-static distclean-rb-default distclean-rb
		-$(Q)$(RM) Makefile $(RUBY_EXTCONF_H) conftest.* mkmf.log
		-$(Q)$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES)
		-$(Q)$(RMDIRS) $(DISTCLEANDIRS) 2> /dev/null || true

realclean: distclean
install: install-so install-rb

install-so: $(DLLIB) $(TIMESTAMP_DIR)/.archdir.-.digest.time
	$(INSTALL_PROG) $(DLLIB) $(RUBYARCHDIR)
clean-static::
	-$(Q)$(RM) $(STATIC_LIB)
install-rb: pre-install-rb do-install-rb install-rb-default
install-rb-default: pre-install-rb-default do-install-rb-default
pre-install-rb: Makefile
pre-install-rb-default: Makefile
do-install-rb:
do-install-rb-default:
pre-install-rb-default:
	@$(NULLCMD)
$(TIMESTAMP_DIR)/.archdir.-.digest.time:
	$(Q) $(MAKEDIRS) $(@D) $(RUBYARCHDIR)
	$(Q) $(TOUCH) $@

site-install: site-install-so site-install-rb
site-install-so: install-so
site-install-rb: install-rb

.SUFFIXES: .c .m .cc .mm .cxx .cpp .o .S

.cc.o:
	$(ECHO) compiling $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.cc.S:
	$(ECHO) translating $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.mm.o:
	$(ECHO) compiling $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.mm.S:
	$(ECHO) translating $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.cxx.o:
	$(ECHO) compiling $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.cxx.S:
	$(ECHO) translating $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.cpp.o:
	$(ECHO) compiling $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.cpp.S:
	$(ECHO) translating $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S | $(CXX) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c -xc++ -,\
  $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.c.o:
	$(ECHO) compiling $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c | $(CC) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c -xc -,\
  $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.c.S:
	$(ECHO) translating $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -S | $(CC) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c -xc -,\
  $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.m.o:
	$(ECHO) compiling $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c | $(CC) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c -xc -,\
  $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


.m.S:
	$(ECHO) translating $(<)
	$(Q) $(if\
  $(or\
    $(and\
      $(findstring json/ext/parser, $(realpath $(<))),\
      $(or\
        $(findstring parser.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /nokogiri, $(realpath $(<))),\
      $(or\
        $(findstring xml_node_set.c, $(<)),\
        $(findstring xslt_stylesheet.c, $(<)),\
        $(findstring xml_document.c, $(<)),\
        $(findstring xml_sax_parser.c, $(<)),\
        $(findstring xml_xpath_context.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring ruby-oci8/ext/oci8, $(realpath $(<))),\
      $(or\
        $(findstring ocinumber.c, $(<)),\
      )\
    ),\
    $(and\
      $(findstring /pg, $(realpath $(<))),\
      $(or\
        $(findstring pg_result.c, $(<)),\
        $(findstring pg_tuple.c, $(<)),\
        $(findstring pg_text_decoder.c, $(<)),\
        $(findstring pg_text_encoder.c, $(<)),\
      )\
    ),\
  ),\
  /home/duncan/work/graal/truffleruby/mxbuild/jdk11/org.truffleruby.bootstrap.launcher/miniruby /home/duncan/work/graal/truffleruby/lib/cext/preprocess.rb $< $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -S | $(CC) -I$(<D) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c -xc -,\
  $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<\
)


$(TARGET_SO): $(OBJS) Makefile
	$(ECHO) linking shared-object digest/$(DLLIB)
	-$(Q)$(RM) $(@)
	$(Q) $(LDSHARED) -o $@ $(OBJS) $(LIBPATH) $(DLDFLAGS) $(LOCAL_LIBS) $(LIBS)



$(OBJS): $(HDRS) $(ruby_headers) Makefile
