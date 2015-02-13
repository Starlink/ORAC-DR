.PHONY: default clean build buildpdf buildhtml install

default: build

docdir      = $${STARLINK_DIR}/docs

STAR2HTML   = $${STARLINK_DIR}/bin/star2html
STARPERL    = $${STARLINK_DIR}/Perl/bin/perl
PDFLATEX    = TEXINPUTS=$${STARLINK_DIR}/share/latexsupport//: pdflatex
HLINK       = $${STARLINK_DIR}/bin/hlink
ORAC_DIR    = $(realpath $(CURDIR)/..)

DOCUMENT   := $(wildcard sun*)
PDF        := $(foreach DOC,$(DOCUMENT),$(DOC)/$(DOC).pdf)
HTMLDIR    := $(foreach DOC,$(DOCUMENT),$(DOC)/$(DOC).htx)
HTMLBUILD  := $(addsuffix .build,$(HTMLDIR))

SUN233_CLASSES = sun233/sun233_classes.tex sun233/sun233_coreclasses.tex
GENERATED_TEX = sun230/sun230.tex

clean:
	rm -rf \
		$(GENERATED_TEX) $(SUN233_CLASSES) \
		$(SUN233_CLASSES:.tex=.aux) \
		$(HTMLDIR) $(HTMLBUILD) \
		$(PDF) \
		$(PDF:.pdf=.aux) \
		$(PDF:.pdf=.log) \
		$(PDF:.pdf=.toc)

build: buildpdf buildhtml

buildpdf: $(PDF)

buildhtml: $(HTMLBUILD)

install: build
	cp $(PDF) $(docdir)/
	cp -r $(HTMLDIR) $(docdir)/
	cd $(docdir); $(HLINK) -d

sun230/sun230.tex: sun230/sun230.pl sun230/sun230_master.tex
	cd $(@D); ORAC_DIR=$(ORAC_DIR) \
		ORAC_INSTRUMENT=UFTI2 \
		$(STARPERL) $(<F)

sun233/sun233.pdf sun233/sun233.htx.build: $(SUN233_CLASSES)

$(SUN233_CLASSES): sun233/mkinclude.csh
	cd $(@D); ORAC_PERL5LIB=$(ORAC_DIR)/lib/perl5 ./$(<F)

%.pdf: %.tex
	cd $(@D); $(PDFLATEX) $(<F)
	cd $(@D); $(PDFLATEX) $(<F)

%.htx.build: %.tex
	cd $(@D); $(STAR2HTML) $(<F)
	touch $@
