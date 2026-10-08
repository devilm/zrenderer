.PHONY: run

# Keep Hangul in the UTF-8 config; GNU Make on Windows may corrupt Unicode arguments.
run:
	bin/zrenderer.exe --config=zrenderer.make.conf --job=4252 --headgear=1361,2809,2059 --garment=65 --weapon=2 --head=3 --gender=male --action=0 --resourcepath="C:/Users/tanak/Downloads"