#!/bin/bash

DIR=`dirname $0`
EXIT_CODE=0

git config --global core.quotepath false

(cat $DIR/dictionary.dic; echo) | sed '/^$/d' | wc -l > /tmp/dictionary.dic
(cat $DIR/dictionary.dic; echo) | sed '/^$/d' >> /tmp/dictionary.dic

echo "SET UTF-8" >> /tmp/dictionary.aff
sudo mv /tmp/dictionary.* /usr/share/hunspell

git diff HEAD^ --name-status | grep "^D" -v | sed 's/^.\t//g' | grep "\.md$" > /tmp/changed_files

go build -o /tmp/spell-checker $DIR/spell-checker.go

while read FILE; do
    echo -n "Проверка файла $FILE на опечатки... ";

    OUTPUT=$(cat "$FILE" | sed 's/https\?:[^ ]*//g' | sed "s/[(][^)]*\.md[)]//g" | sed "s/[(]files[^)]*[)]//g" | hunspell -d dictionary,russian-aot-utf8,ru_RU,de_DE-utf8,en_US-utf8 | /tmp/spell-checker);
    OUTPUT_EXIT_CODE=$?

    if [ $OUTPUT_EXIT_CODE -ne 0 ]; then
        EXIT_CODE=1
        echo "ошибка";
        echo "$OUTPUT";
    else
        echo "пройдена";
    fi

    rm -f /tmp/file.html
    blackfriday-tool "$FILE" /tmp/file.html

    if [ -f "/tmp/file.html" ]; then
        grep -Po '(?<=href=")http[^"]*(?=")' "/tmp/file.html" > /tmp/links

        if [ -s /tmp/links ]; then
            echo "Проверка файла $FILE на недоступные ссылки... ";

            while read LINK; do
                REGEXP_LINK=$(echo $LINK | sed 's/[]\.|$(){}?+*^[]/\\&/g')
                LINK=$(echo "$LINK" | sed -e 's/\[/\\\[/g' -e 's/\]/\\\]/g' -e 's/\&amp;/\&/g')
                status=$(curl --insecure -XGET -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36" -m 10 -L -s --head -w %{http_code} $LINK -o /dev/null)
                expectedStatus=$(grep -oP "[^,]+,$REGEXP_LINK$" $DIR/known_url.csv | cut -d',' -f1)

                if [ -z "$expectedStatus" ]; then
                    expectedStatus="200"
                fi

                if [ "$status" != "$expectedStatus" -a "$status" != "200" ]; then
                    EXIT_CODE=1
                    echo "Ссылка $LINK ... недоступна с кодом $status, ожидается $expectedStatus";
                    echo
                fi

            done < /tmp/links

            echo
        fi
    fi

    echo
done < /tmp/changed_files

exit $EXIT_CODE
