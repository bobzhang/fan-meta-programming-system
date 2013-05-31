VERSION = 0.1
export VERSION

PREFIX ?= $(shell dirname $(shell dirname `ocamlc -where`))
LIBPREFIX ?= `ocamlc -where`
# the path to install the basic cmi files
LIBDIR ?= $(LIBPREFIX)/fan



# the path to install binary
BINDIR ?= $(PREFIX)/bin

OCAMLBUILD ?= ocamlbuild





BCOLD=_build/cold/
BHOT=_build/src/
EXES=fan.byte fan.native fanX.byte

LIBTARGETS = fgram.cma fgram.cmx fgram.cmxs rts.cma rts.cmxa rts.cmxs fanTop.cma fan_full.cma
BINTARGETS = fan.byte fan.native 


STDTARGETS = fAst.cmi fAstN.cmi

ICTARGETS=$(addprefix _build/cold,$(TARGETS))

BYTEXLIBS = mkFan.cma fEval.cmo fanX.cmo

sbyteX: $(addprefix $(BHOT),$(BYTEXLIBS))
	ocamlbuild $(addprefix src/, $(BYTEXLIBS))
	cd $(BHOT);	ocamlc.opt -linkall -I +compiler-libs dynlink.cma mkFan.cma  ocamlcommon.cma ocamlbytecomp.cma ocamltoplevel.cma fEval.cmo fanX.cmo -o fanX.byte


cbyteX:  $(addprefix $(BCOLD),$(BYTEXLIBS))
	ocamlbuild $(addprefix cold/, $(BYTEXLIBS))
	cd $(BCOLD);	ocamlc.opt -linkall -I +compiler-libs dynlink.cma mkFan.cma  ocamlcommon.cma ocamlbytecomp.cma ocamltoplevel.cma fEval.cmo fanX.cmo -o fanX.byte


_build/src/mkFan.cma:src/mkFan.ml
	ocamlbuild src/mkFan.cma

_build/src/fanX.cmo:src/fanX.ml
	ocamlbuild src/fanX.cmo

_build/cold/mkFan.cma:
	ocamlbuild cold/fanX.cma
build:
	$(OCAMLBUILD) $(addprefix cold/,$(LIBTARGETS) $(BINTARGETS))
	make cbyteX


install:
	install -m 0755 $(addprefix $(BCOLD), $(BINTARGETS)) $(addprefix $(BCOLD), fanX.byte) \
	$(BINDIR)
	if ! [ -a $(LIBDIR) ]; then mkdir $(LIBDIR); fi;
	echo "installing to " $(LIBDIR)
	install -m 0755 $(addprefix $(BCOLD), FAstN.cmi FAst.cmi) $(LIBPREFIX)
	install -m 0755 $(BCOLD)*.cmi $(addprefix $(BCOLD), $(LIBTARGETS)) $(LIBDIR)
metainstall:
	ocamlfind install fan META

world:
	make build
	make uninstall
	make install

hotworld:
	make hotbuild
	make uninstall
	make hotinstall

hotinstall:
	install -m 0755 $(addprefix $(BHOT), $(BINTARGETS)) $(addprefix $(BHOT), fanX.byte) \
	$(BINDIR)
	if ! [ -a $(LIBDIR) ]; then mkdir $(LIBDIR); fi;
	echo "installing to " $(LIBDIR)
	install -m 0755 $(addprefix $(BHOT), FAstN.cmi FAst.cmi) $(LIBPREFIX)
	install -m 0755 $(BHOT)*.cmi $(addprefix $(BHOT), $(LIBTARGETS)) $(LIBDIR)

hotbuild:
	$(OCAMLBUILD) $(addprefix src/,$(LIBTARGETS) $(BINTARGETS))
	make sbyteX

uninstall:
	make libuninstall

libuninstall:
	ocamlfind remove fan 

top:
	ocamlbuild -I src foo.otarget

cleansrc:
	rm -rf _build/src
cleancold:
	rm -rf _build/cold
cleantmp:
	rm -rf _build/tmp
cleandemo:
	rm -rf _build/demo
cleantest:
	rm -rf _build/test

boot:
	cd ~/fan/ && ocamlbuild -I src boot/fan.native
stat:
	rm -rf stat/*
	git_stats . stat


# ls *.mli | sed s/.mli$// > foo.odocl
doc:
	ocamlbuild src/foo.docdir/index.html
updoc:
	make doc
	rm -rf ~/Dropbox/fanweb/foo.docdir
	mv _build/src/foo.docdir ~/Dropbox/fanweb/

.PHONY: top doc byteX
