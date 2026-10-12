.PHONY: build docker-build run run-effect

build:
	dub build --root=cli

docker-build:
	docker compose build

# Keep Hangul in the UTF-8 config; GNU Make on Windows may corrupt Unicode arguments.
run:
	bin/zrenderer.exe --job=4252 --headgear=2174,2809 --garment=282 --weapon=2 --head=3 --gender=male --resourcepath="C:/Users/tanak/Downloads"

run-effect:
	bin/zrenderer.exe --config=zrenderer.texture.conf --texture="texture\effect\efst_c_dark_lord_cloak\darklordcloak.str" --job=4255 --headgear=1361,2136 --garment=1 --weapon=2 --head=3 --gender=male --headPalette=1 --action=32 --resourcepath="C:/Users/tanak/Downloads"
    
	bin/zrenderer.exe --config=zrenderer.texture.conf --texture="texture\effect\c_released_ground\ki.str" --job=4255 --headgear=1361,2136 --garment=1 --weapon=2 --head=3 --gender=male --headPalette=1 --action=32 --resourcepath="C:/Users/tanak/Downloads"
	
	bin/zrenderer.exe --config=zrenderer.texture.conf --texture="texture\effect\efst_c_ros2023_cape_1\ros2023_1st.str" --job=4255 --headgear=1361,2136 --garment=1 --weapon=2 --head=3 --gender=male --headPalette=1 --action=32 --resourcepath="C:/Users/tanak/Downloads"
