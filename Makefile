.PHONY: run

# Keep Hangul in the UTF-8 config; GNU Make on Windows may corrupt Unicode arguments.
run:
	bin/zrenderer.exe --job=4252 --headgear=2174,2809 --garment=282 --weapon=2 --head=3 --gender=male --resourcepath="C:/Users/tanak/Downloads"

run-effect:
	bin/zrenderer.exe --config=zrenderer.make.conf --job=4252 --headgear=1361,2809 --garment=1 --weapon=2 --head=3 --gender=male --action=32 --resourcepath="C:/Users/tanak/Downloads"