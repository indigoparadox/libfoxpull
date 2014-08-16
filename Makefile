
SOURCES = foxpullencryptor.vala sslbridge.c
VALAC = valac
VALAARGS = -g
PKGS = --pkg webkit2gtk-3.0 --pkg base32alloc --pkg json-glib-1.0 --pkg libsoup-2.4 -X -lbase32alloc -X -lssl -X -lbstrlib

libfoxpull.so:
	$(VALAC) $(VALAARGS) --library=libfoxpull -H foxpull.h $(PKGS) $(SOURCES) -X -fPIC -X -shared -o libfoxpull.so

test: libfoxpull.so
	$(VALAC) $(VALAARGS) --vapidir=. --pkg libfoxpull --pkg json-glib-1.0 -X -I. -X -L. -X -lfoxpull test.vala

clean:
	rm *.so
	rm foxpull.h
	rm *.vapi
	rm test

