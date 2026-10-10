.PHONY: build run run-effect

build:
	dub build --root=cli
# Keep Hangul in the UTF-8 config; GNU Make on Windows may corrupt Unicode arguments.
run:
	bin/zrenderer.exe --job=4252 --headgear=2174,2809 --garment=282 --weapon=2 --head=3 --gender=male --resourcepath="C:/Users/tanak/Downloads"

run-effect:
	bin/zrenderer.exe --texture="texture\effect\c_released_ground\ki.str" --config=zrenderer.make.conf --job=4252 --headgear=1361,2136 --garment=1 --weapon=2 --head=3 --gender=male --action=0 --resourcepath="C:/Users/tanak/Downloads"