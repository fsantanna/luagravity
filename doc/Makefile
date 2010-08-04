all: intro api meta meta_api
	cat intro_menu.html _intro.html _api.html bottom.html > index.html
	cat meta_menu.html _meta.html _meta_api.html bottom.html > meta.html
	rm _*.html

intro:
	markdown intro.txt > _intro.html

api:
	markdown api.txt > _api.html

meta:
	markdown meta.txt > _meta.html

meta_api:
	markdown meta_api.txt > _meta_api.html

upload:
	scp doc.css index.html meta.html l.gif *.png luagravity.png \
		francisco@www.lua.inf.puc-rio.br:/home/francisco/public_html/luagravity/
