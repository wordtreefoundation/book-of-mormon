DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

if [ -d "$DIR/_tmp" ]; then
	mv $DIR/_tmp/* $DIR/content/
	rmdir $DIR/_tmp
fi