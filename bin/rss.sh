#!/usr/bin/env sh

pandoc-rss $(./finalized.py) > site/rss.xml

PREFIX=$(cat <<-END
  <?xml version="1.0" encoding="UTF-8" ?>
  <?xml-stylesheet href="./assets/rss.xsl" type="text/xsl"?>
  <rss version="2.0">
  <channel>
    <title>Takashi Idobe</title>
    <link>https://takashiidobe.com</link>
  <description>Thoughts on Programming</description>
END
)

# prefix
echo $PREFIX | cat - site/rss.xml | sponge site/rss.xml

# suffix
echo "</channel></rss>" >> site/rss.xml
