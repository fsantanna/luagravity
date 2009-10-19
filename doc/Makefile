all: intro api meta meta_api
	cat intro_menu.html _intro.html _api.html > index.html
	cat meta_menu.html _meta.html _meta_api.html > meta.html
	rm _*.html

intro:
	markdown intro.txt > _intro.html

api:
	markdown api.txt > _api.html

meta:
	markdown meta.txt > _meta.html

meta_api:
	markdown meta_api.txt > _meta_api.html

release:
	tar cvzf homepage.tgz ../../luagravity-0.5.tgz ../../ldirectfb-0.1.tgz *
