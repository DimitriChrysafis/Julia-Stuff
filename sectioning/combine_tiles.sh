#!/bin/bash

TILE_SIZE=5000
WIDTH=20000
HEIGHT=20000

NUM_TILES_X=$((WIDTH / TILE_SIZE))
NUM_TILES_Y=$((HEIGHT / TILE_SIZE))

cmd="magick convert -size ${WIDTH}x${HEIGHT} xc:black"

for x in $(seq 0 $((NUM_TILES_X - 1))); do
  for y in $(seq 0 $((NUM_TILES_Y - 1))); do
    tile_x=$((x * TILE_SIZE))
    tile_y=$((y * TILE_SIZE))
    tile="Julia/tile_${tile_x}_${tile_y}.png"
    geometry="+${tile_x}+${tile_y}"
    cmd="$cmd \\( $tile -geometry $geometry \\) -composite"
  done
done

cmd="$cmd FINAL.png"

echo "Executing command:"
echo $cmd
$cmd
