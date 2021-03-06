POFILES = $(wildcard *.po)
MOFILES := $(POFILES:%.po=locale/%/LC_MESSAGES/Zonemaster-Engine.mo)
POTFILE = Zonemaster-Engine.pot
PMFILES = $(shell find ../lib -type f -name '*.pm' | sort)
TESTMODULEFILES = $(shell find ../lib/Zonemaster/Engine/Test -type f -name '*.pm' | sort)

.PHONY: all touch-po update-po extract-pot

all: ${MOFILES} modules.txt
	@echo
	@echo Remember to make sure all of the above names are in the
	@echo MANIFEST file, or they will not be installed.
	@echo

touch-po:
	@touch $(POTFILE) $(POFILES)

update-po: extract-pot $(POFILES)

extract-pot:
	@xgettext --output $(POTFILE) --sort-output --add-comments --language=Perl --from-code=UTF-8 -k__ -k\$$__ -k%__ -k__x -k__n:1,2 -k__nx:1,2 -k__xn:1,2 -kN__ -kN__n:1,2 -k__p:1c,2 -k__np:1c,2,3 -kN__p:1c,2 -kN__np:1c,2,3 $(PMFILES)

$(POTFILE): extract-pot

%.po: $(POTFILE)
	@msgmerge --update --backup=none --quiet --no-location $(MSGMERGE_OPTS) $@ $(POTFILE)

$(MOFILES): locale/%/LC_MESSAGES/Zonemaster-Engine.mo: %.po
	@mkdir -p locale/$*/LC_MESSAGES
	@# It must be 'Zonemaster-Engine' because that is defined in "name" in Makefile.PL
	@perl -e 'use Locale::Msgfmt; msgfmt({in => $$ARGV[0], out => $$ARGV[1]});' $< locale/$*/LC_MESSAGES/Zonemaster-Engine.mo
	@echo locale/$*/LC_MESSAGES/Zonemaster-Engine.mo

show-fuzzy:
	@for f in $(POFILES) ; do msgattrib --only-fuzzy $$f ; done

modules.txt: $(TESTMODULEFILES)
	echo $(TESTMODULEFILES) | xargs basename -s .pm -a | grep -vE '^Basic$$' | sort > modules.txt
