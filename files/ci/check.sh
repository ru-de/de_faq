#!/bin/bash

DIR=`dirname $0`

git config --global core.quotepath false

PULL_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

curl "https://github-api-bot.herokuapp.com/diff?repo=${GITHUB_REPOSITORY}&pr=${PULL_NUMBER}" > /tmp/pr.diff

if [ "$?" != "0" ]; then
    echo "Can't get github pull request diff, probably rate limit? Try to restart CI build"
    exit 1
fi

cat /tmp/pr.diff | diff_liner > /tmp/pr_liner.json

rm -f /tmp/comments.json
touch /tmp/comments.json

curl -s -X GET -G https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PULL_NUMBER}/files | jq -r '.[] | .filename' | grep "^D" -v | sed 's/^.\t//g' | grep "\.md$" > /tmp/changed_files

while read FILE; do
    COMMIT=$(git log --pretty=format:"%H" -1 "$FILE");
    echo "Проверка изменений в файле $FILE на опечатки... ";

    cat "$FILE" | sed 's/https\?:[^ ]*//g' | sed "s/[(][^)]*\.md[)]//g" | sed "s/[(]files[^)]*[)]//g" | hunspell -d dictionary,russian-aot-utf8,ru_RU-utf8,de_DE-utf8,en_US-utf8 > /tmp/hunspell.out
    cat /tmp/hunspell.out | hunspell_parser > /tmp/hunspell_parsed.json
    /tmp/check_spell -file "$FILE" -commit=$COMMIT -pr-liner /tmp/pr_liner.json -hunspell-parsed-file /tmp/hunspell_parsed.json >> /tmp/comments.json

    echo "Проверка изменений в файле $FILE на недоступные ссылки... ";

    /tmp/check_links -file "$FILE" -commit=$COMMIT -pr-liner /tmp/pr_liner.json -expected-codes files/ci/expected_codes.csv >> /tmp/comments.json

    echo
done < /tmp/changed_files

jq -s '[.[][]]' /tmp/comments.json > /tmp/comments_array.json

cat /tmp/comments_array.json

EXIT_CODE=0

if [ "$(cat /tmp/comments_array.json)" != "[]" ]; then
    curl "https://github-api-bot.herokuapp.com/comments?repo=${GITHUB_REPOSITORY}&pr=${PULL_NUMBER}" > /tmp/pr_comments.json

    if [ "$?" != "0" ]; then
        echo "Can't get github comments, probably rate limit? Try to restart ci build"
        exit 1
    fi

    github_comments_diff -comments /tmp/comments_array.json -exists-comments /tmp/pr_comments.json > /tmp/send_comments.json

    curl -XPOST "https://github-api-bot.herokuapp.com/send_review?repo=${GITHUB_REPOSITORY}&pr=${PULL_NUMBER}&body=Спасибо%20за%20PR.%20Обратите%20внимание%20на%20результаты%20автоматической%20проверки%20орфографии%20и%20ссылок" -d @/tmp/send_comments.json

    EXIT_CODE=1
fi

exit $EXIT_CODE
