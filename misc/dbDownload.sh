WORK_DIR=$(cd "$(dirname "$0")"; pwd)
REPO_PATH=$1
if test "1" = "0" \
    || test "x-$REPO_PATH" = "x-" \
    ; then
    exit 1
fi

_OLD_DIR=$(pwd)
cd "$REPO_PATH"

BRANCH=`git branch | grep '^\* ' | sed -e 's/^\* //g'`

git checkout .
git fetch --all
git reset --hard origin/$BRANCH
git clean -xdf
git pull
if ! test "$?" = "0"; then
    cd "$_OLD_DIR"
    exit 1
fi
git gc --prune=now

cd "$_OLD_DIR"

exit 0

