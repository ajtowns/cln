#! /usr/bin/make
NAME=MtGox's Cold Wallet

# Needs to have oneof support: Ubuntu vivid's is too old :(
PROTOCC:=protoc-c

# Alpha has checksequenceverify, segregated witness+input-amount-in-sig+confidentual-transactions, schnorr, checklocktimeverify
FEATURES := -DHAS_CSV=1 -DALPHA_TXSTYLE=1 -DUSE_SCHNORR=1 -DHAS_CLTV=1
# Bitcoin uses DER for signatures (Add BIP68 if it's supported)
#FEATURES := -DSCRIPTS_USE_DER #-DHAS_BIP68

TEST_CLI_PROGRAMS :=				\
	test-cli/check-commit-sig		\
	test-cli/close-channel			\
	test-cli/create-anchor-tx		\
	test-cli/create-close-tx		\
	test-cli/create-commit-spend-tx		\
	test-cli/create-commit-tx		\
	test-cli/create-htlc-spend-tx		\
	test-cli/create-steal-tx		\
	test-cli/get-anchor-depth		\
	test-cli/open-anchor			\
	test-cli/open-channel			\
	test-cli/open-commit-sig		\
	test-cli/txid-of			\
	test-cli/update-channel			\
	test-cli/update-channel-accept		\
	test-cli/update-channel-complete	\
	test-cli/update-channel-htlc		\
	test-cli/update-channel-htlc-complete	\
	test-cli/update-channel-htlc-remove	\
	test-cli/update-channel-signature

TEST_PROGRAMS :=				\
	test/test_state_coverage		\
	test/onion_key				\
	test/test_onion

BITCOIN_OBJS :=					\
	bitcoin/address.o			\
	bitcoin/base58.o			\
	bitcoin/pubkey.o			\
	bitcoin/script.o			\
	bitcoin/shadouble.o			\
	bitcoin/signature.o			\
	bitcoin/tx.o

HELPER_OBJS :=					\
	close_tx.o				\
	commit_tx.o				\
	find_p2sh_out.o				\
	funding.o				\
	lightning.pb-c.o			\
	opt_bits.o				\
	permute_tx.o				\
	pkt.o					\
	protobuf_convert.o			\
	test-cli/gather_updates.o		\
	version.o

CCAN_OBJS :=					\
	ccan-crypto-ripemd160.o			\
	ccan-crypto-sha256.o			\
	ccan-crypto-shachain.o			\
	ccan-err.o				\
	ccan-list.o				\
	ccan-noerr.o				\
	ccan-opt-helpers.o			\
	ccan-opt-parse.o			\
	ccan-opt-usage.o			\
	ccan-opt.o				\
	ccan-read_write_all.o			\
	ccan-str-hex.o				\
	ccan-str.o				\
	ccan-take.o				\
	ccan-tal-grab_file.o			\
	ccan-tal-str.o				\
	ccan-tal.o

# For tests
CCAN_EXTRA_OBJS :=				\
	ccan-hash.o				\
	ccan-htable.o

CDUMP_OBJS := ccan-cdump.o ccan-strmap.o

DOC_ONION_DIAG :=				\
	doc/onion-ecdh.dfmt			\
	doc/onion-secrets.dfmt			\
	doc/onion-wrap.dfmt			\
	doc/onion-unwrap.dfmt			\
	doc/onion-init.dfmt

PROGRAMS := $(TEST_CLI_PROGRAMS) $(TEST_PROGRAMS)

HEADERS := $(filter-out gen_*, $(wildcard *.h)) $(wildcard bitcoin/*.h) gen_state_names.h

CCANDIR := ccan/
CFLAGS := -g -Wall -I $(CCANDIR) -I secp256k1/include/ -DVALGRIND_HEADERS=1 $(FEATURES)
LDLIBS := -lcrypto -lprotobuf-c
$(PROGRAMS): CFLAGS+=-I.

default: $(PROGRAMS)

# These don't work in parallel, so we open-code them
test-cli-tests: $(TEST_CLI_PROGRAMS)
	cd test-cli; scripts/shutdown.sh 2>/dev/null || true
	set -e; cd test-cli; for args in "" --steal --unilateral --htlc-onchain; do scripts/setup.sh && scripts/test.sh $$args && scripts/shutdown.sh; done

test-onion: test/test_onion test/onion_key
	set -e; TMPF=/tmp/onion.$$$$; test/test_onion --generate $$(test/onion_key --pub `seq 20`) > $$TMPF; for k in `seq 20`; do test/test_onion --decode $$(test/onion_key --priv $$k) < $$TMPF > $$TMPF.unwrap; mv $$TMPF.unwrap $$TMPF; done; rm -f $$TMPF

test-onion2: test/test_onion test/onion_key
	set -e; TMPF=/tmp/onion.$$$$; python test/test_onion.py generate $$(test/onion_key --pub `seq 20`) > $$TMPF; for k in `seq 20`; do test/test_onion --decode $$(test/onion_key --priv $$k) < $$TMPF > $$TMPF.unwrap; mv $$TMPF.unwrap $$TMPF; done; rm -f $$TMPF

test-onion3: test/test_onion test/onion_key
	set -e; TMPF=/tmp/onion.$$$$; test/test_onion --generate $$(test/onion_key --pub `seq 20`) > $$TMPF; for k in `seq 20`; do python test/test_onion.py decode $$(test/onion_key --priv $$k) $$(test/onion_key --pub $$k) < $$TMPF > $$TMPF.unwrap; mv $$TMPF.unwrap $$TMPF; done; rm -f $$TMPF

test-onion4: test/test_onion test/onion_key
	set -e; TMPF=/tmp/onion.$$$$; python test/test_onion.py generate $$(test/onion_key --pub `seq 20`) > $$TMPF; for k in `seq 20`; do python test/test_onion.py decode $$(test/onion_key --priv $$k) $$(test/onion_key --pub $$k) < $$TMPF > $$TMPF.unwrap; mv $$TMPF.unwrap $$TMPF; done; rm -f $$TMPF

check: test-cli-tests test-onion

full-check: check $(TEST_PROGRAMS)
	test/test_state_coverage

TAGS: FORCE
	$(RM) TAGS; find . -name '*.[ch]' | xargs etags --append
FORCE::

ccan/ccan/cdump/tools/cdump-enumstr: ccan/ccan/cdump/tools/cdump-enumstr.o $(CDUMP_OBJS) $(CCAN_OBJS)

gen_state_names.h: state_types.h ccan/ccan/cdump/tools/cdump-enumstr
	ccan/ccan/cdump/tools/cdump-enumstr state_types.h > $@

# We build a static libsecpk1, since we need schnorr for alpha
# (and it's not API stable yet!).
libsecp256k1.a: secp256k1/libsecp256k1.la

secp256k1/libsecp256k1.la:
	cd secp256k1 && ./autogen.sh && ./configure --enable-static=yes --enable-shared=no --enable-tests=no --enable-module-schnorr=yes --enable-module-ecdh=yes --libdir=`pwd`/..
	$(MAKE) -C secp256k1 install-exec

lightning.pb-c.c lightning.pb-c.h: lightning.proto
	$(PROTOCC) lightning.proto --c_out=.

$(TEST_CLI_PROGRAMS): % : %.o $(HELPER_OBJS) $(BITCOIN_OBJS) $(CCAN_OBJS) libsecp256k1.a
$(TEST_PROGRAMS): % : %.o $(BITCOIN_OBJS) $(CCAN_OBJS) $(CCAN_EXTRA_OBJS) version.o libsecp256k1.a
$(PROGRAMS:=.o) $(HELPER_OBJS): $(HEADERS)

$(CCAN_OBJS) $(HELPER_OBJS) $(PROGRAM_OBJS) $(BITCOIN_OBJS) $(CDUMP_OBJS): ccan/config.h

ccan/config.h: ccan/tools/configurator/configurator
	$< > $@

doc/deployable-lightning.pdf: doc/deployable-lightning.lyx doc/bitcoin.bib
	lyx -E pdf $@ $<

doc/deployable-lightning.tex: doc/deployable-lightning.lyx
	lyx -E latex $@ $<

state-diagrams: doc/normal-states.svg doc/simplified-states.svg doc/error-states.svg doc/full-states.svg

%.dvi: %.dfmt
	doc/dformat.awk < $< | groff -p -T dvi -- > $@
%.ps: %.dfmt
	doc/dformat.awk < $< | groff -p -- > $@
%.eps: %.ps
	ps2epsi $< $@
%.svg: %.dvi
	dvisvgm $< --no-fonts -s > $@

doc/onion.pdf: doc/onion.lyx $(DOC_ONION_DIAG:.dfmt=.eps)
	lyx -E pdf $@ $<

doc-onion-svg: $(DOC_ONION_DIAG:.dfmt=.svg)
doc-onion-eps: $(DOC_ONION_DIAG:.dfmt=.eps)

%.svg: %.dot
	dot -Tsvg $< > $@ || (rm -f $@; false)

doc/simplified-states.dot: test/test_state_coverage
	test/test_state_coverage --dot --dot-simplify > $@

doc/normal-states.dot: test/test_state_coverage
	test/test_state_coverage --dot > $@

doc/error-states.dot: test/test_state_coverage
	test/test_state_coverage --dot-all --dot-include-errors > $@

doc/full-states.dot: test/test_state_coverage
	test/test_state_coverage --dot-all --dot-include-errors --dot-include-nops > $@

gen_version.h: FORCE
	@(echo "#define VERSION \"`git describe --always --dirty`\"" && echo "#define VERSION_NAME \"$(NAME)\"" && echo "#define BUILD_FEATURES \"$(FEATURES)\"") > $@.new
	@if cmp $@.new $@ >/dev/null 2>&2; then rm -f $@.new; else mv $@.new $@; fi

version.o: gen_version.h

update-ccan:
	mv ccan ccan.old
	DIR=$$(pwd)/ccan; cd ../ccan && ./tools/create-ccan-tree -a $$DIR `cd $$DIR.old/ccan && find * -name _info | sed s,/_info,, | sort` $(CCAN_NEW)
	mkdir -p ccan/tools/configurator
	cp ../ccan/tools/configurator/configurator.c ccan/tools/configurator/
	$(MAKE) ccan/config.h
	grep -v '^CCAN version:' ccan.old/README > ccan/README
	echo CCAN version: `git -C ../ccan describe` >> ccan/README
	$(RM) -r ccan.old

distclean: clean
	$(MAKE) -C secp256k1/ distclean || true
	$(RM) libsecp256k1.a

maintainter-clean: distclean
	@echo 'This command is intended for maintainers to use; it'
	@echo 'deletes files that may need special tools to rebuild.'
	$(RM) lightning.pb-c.c lightning.pb-c.h ccan/config.h gen_version.h
	$(RM) doc/deployable-lightning.pdf

clean:
	$(MAKE) -C secp256k1/ clean || true
	$(RM) libsecp256k1.{a,la}
	$(RM) $(PROGRAMS) test-cli/leak-anchor-sigs
	$(RM) bitcoin/*.o *.o $(PROGRAMS:=.o) $(CCAN_OBJS) $(CCAN_EXTRA_OBJS)
	$(RM) doc/deployable-lightning.{aux,bbl,blg,dvi,log,out,tex}

ccan-tal.o: $(CCANDIR)/ccan/tal/tal.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-tal-str.o: $(CCANDIR)/ccan/tal/str/str.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-tal-grab_file.o: $(CCANDIR)/ccan/tal/grab_file/grab_file.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-take.o: $(CCANDIR)/ccan/take/take.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-list.o: $(CCANDIR)/ccan/list/list.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-read_write_all.o: $(CCANDIR)/ccan/read_write_all/read_write_all.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-str.o: $(CCANDIR)/ccan/str/str.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-opt.o: $(CCANDIR)/ccan/opt/opt.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-opt-helpers.o: $(CCANDIR)/ccan/opt/helpers.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-opt-parse.o: $(CCANDIR)/ccan/opt/parse.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-opt-usage.o: $(CCANDIR)/ccan/opt/usage.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-err.o: $(CCANDIR)/ccan/err/err.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-noerr.o: $(CCANDIR)/ccan/noerr/noerr.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-str-hex.o: $(CCANDIR)/ccan/str/hex/hex.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-crypto-shachain.o: $(CCANDIR)/ccan/crypto/shachain/shachain.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-crypto-sha256.o: $(CCANDIR)/ccan/crypto/sha256/sha256.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-crypto-ripemd160.o: $(CCANDIR)/ccan/crypto/ripemd160/ripemd160.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-cdump.o: $(CCANDIR)/ccan/cdump/cdump.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-strmap.o: $(CCANDIR)/ccan/strmap/strmap.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-hash.o: $(CCANDIR)/ccan/hash/hash.c
	$(CC) $(CFLAGS) -c -o $@ $<
ccan-htable.o: $(CCANDIR)/ccan/htable/htable.c
	$(CC) $(CFLAGS) -c -o $@ $<


