# cl-yesql

.POSIX:
.SUFFIXES:
.SUFFIXES: .asd .lisp .txt

VERSION=$(shell cat version)
CL_YESQL=cl-yesql
PACKAGE=cl-yesql-$(VERSION)

# variables
DOTEMACS=$(HOME)/.emacs.d/init.el

ASDSRCS=$(wildcard *.asd)
LISPSRCS=$(wildcard *.lisp)
SRCS=$(ASDSRCS) $(LISPSRCS)

# paths
scrdir=.

prefix=/usr/local
exec_prefix=$(prefix)
bindir=$(exec_prefix)/bin
libdir=$(exec_prefix)/lib
libexecdir=$(exec_prefix)/libexec/$(CL_YESQL)
lispdir=$(exec_prefix)/lisp/$(CL_YESQL)

datarootdir=$(prefix)/share
datadir=$(datarootdir)/$(CL_YESQL)
docdir=$(datarootdir)/doc/$(CL_YESQL)
infodir=$(datarootdir)/info

# programs
INSTALL=/usr/bin/install

all:

clean:

distclean: clean

dist: distclean

install: all installdirs
	cp version $(DESTDIR)$(lispdir)
	cp $(SRCS) $(DESTDIR)$(lispdir)
	cp -R t $(DESTDIR)$(lispdir)
	cp README.md $(DESTDIR)$(docdir)

uninstall:
	-rm -rf $(lispdir)
	-rm -rf $(docdir)

installdirs:
	mkdir -p $(DESTDIR)$(lispdir)
	mkdir -p $(DESTDIR)$(docdir)

info:

README.txt: doc/README.org
	emacs --batch -l $(DOTEMACS) --visit $< -f org-ascii-export-to-ascii
	mv doc/README.txt .

check:

.PHONY: all clean distclean dist install installdirs uninstall info check
