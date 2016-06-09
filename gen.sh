OLDIFS=$IFS
for B in 1nephi,22 2nephi,33 jacob,7 enos,1 jarom,1 omni,1 wom,1 mosiah,29 alma,63 helaman,16 3nephi,30 4nephi,1 mormon,9 ether,15 moroni,10; do
    IFS=","; set $B
    BOOK=$1
    CHAPTERS=$2
    IFS=$OLDIFS
    echo "Generating $BOOK..."
    echo "# $BOOK" >$BOOK.md
    for C in `seq -w $CHAPTERS`; do
    	mkdir -p $BOOK
    	echo "[Chapter $(printf $d $C)]($BOOK/chapter_$C.md)" >>$BOOK.md
        bomdb show "$BOOK $C" --markdown --linesep="\\n\\n" >$BOOK/chapter_$C.md
    done
done

