DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

mkdir -p $DIR/_tmp

mv $DIR/content/* $DIR/_tmp
mv $DIR/_tmp/1nephi* $DIR/content/