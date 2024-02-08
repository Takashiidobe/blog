<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:atom="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <title><xsl:value-of select="/rss/channel/title"/> Feed</title>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"/>
        <style>
::backdrop,:root{--sans-font:-apple-system,BlinkMacSystemFont,"Avenir Next",Avenir,"Nimbus Sans L",Roboto,"Noto Sans","Segoe UI",Arial,Helvetica,"Helvetica Neue",sans-serif;--mono-font:Consolas,Menlo,Monaco,"Andale Mono","Ubuntu Mono",monospace;--standard-border-radius:5px;--bg:#fff;--accent-bg:#f5f7ff;--text:#212121;--text-light:#585858;--border:#898EA4;--accent:#0d47a1;--accent-hover:#1266e2;--accent-text:var(--bg);--code:#d81b60;--preformatted:#444;--marked:#ffdd33;--disabled:#efefef}@media (prefers-color-scheme:dark){::backdrop,:root{color-scheme:dark;--bg:#212121;--accent-bg:#2b2b2b;--text:#dcdcdc;--text-light:#ababab;--accent:#ffb300;--accent-hover:#ffe099;--accent-text:var(--bg);--code:#f06292;--preformatted:#ccc;--disabled:#111}img,video{opacity:.8}}*,::after,::before{box-sizing:border-box}input,progress,select,textarea{appearance:none;-webkit-appearance:none;-moz-appearance:none}html{font-family:var(--sans-font);scroll-behavior:smooth}body{color:var(--text);background-color:var(--bg);font-size:1.15rem;line-height:1.5;display:grid;grid-template-columns:1fr min(45rem,90%) 1fr;margin:0}body>*{grid-column:2}body>header{background-color:var(--accent-bg);border-bottom:1px solid var(--border);text-align:center;padding:0 .5rem 2rem .5rem;grid-column:1/-1}body>header>:only-child{margin-block-start:2rem}body>header h1{max-width:1200px;margin:1rem auto}body>header p{max-width:40rem;margin:1rem auto}main{padding-top:1.5rem}body>footer{margin-top:4rem;padding:2rem 1rem 1.5rem 1rem;color:var(--text-light);font-size:.9rem;text-align:center;border-top:1px solid var(--border)}h1{font-size:3rem}h2{font-size:2.6rem;margin-top:3rem}h3{font-size:2rem;margin-top:3rem}h4{font-size:1.44rem}h5{font-size:1.15rem}h6{font-size:.96rem}p{margin:1.5rem 0}h1,h2,h3,h4,h5,h6,p{overflow-wrap:break-word}h1,h2,h3{line-height:1.1}@media only screen and (max-width:720px){h1{font-size:2.5rem}h2{font-size:2.1rem}h3{font-size:1.75rem}h4{font-size:1.25rem}}a,a:visited{color:var(--accent)}a:hover{text-decoration:none}.button,a.button,button,input[type=button],input[type=reset],input[type=submit],label[type=button]{border:1px solid var(--accent);background-color:var(--accent);color:var(--accent-text);padding:.5rem .9rem;text-decoration:none;line-height:normal}.button[aria-disabled=true],button[disabled],input:disabled,select:disabled,textarea:disabled{cursor:not-allowed;background-color:var(--disabled);border-color:var(--disabled);color:var(--text-light)}input[type=range]{padding:0}abbr[title]{cursor:help;text-decoration-line:underline;text-decoration-style:dotted}.button:not([aria-disabled=true]):hover,button:enabled:hover,input[type=button]:enabled:hover,input[type=reset]:enabled:hover,input[type=submit]:enabled:hover,label[type=button]:hover{background-color:var(--accent-hover);border-color:var(--accent-hover);cursor:pointer}.button:focus-visible,button:focus-visible:where(:enabled),input:enabled:focus-visible:where([type=submit],[type=reset],[type=button]){outline:2px solid var(--accent);outline-offset:1px}header>nav{font-size:1rem;line-height:2;padding:1rem 0 0 0}header>nav ol,header>nav ul{align-content:space-around;align-items:center;display:flex;flex-direction:row;flex-wrap:wrap;justify-content:center;list-style-type:none;margin:0;padding:0}header>nav ol li,header>nav ul li{display:inline-block}header>nav a,header>nav a:visited{margin:0 .5rem 1rem .5rem;border:1px solid var(--border);border-radius:var(--standard-border-radius);color:var(--text);display:inline-block;padding:.1rem 1rem;text-decoration:none}header>nav a.current,header>nav a:hover,header>nav a[aria-current=page]{border-color:var(--accent);color:var(--accent);cursor:pointer}@media only screen and (max-width:720px){header>nav a{border:none;padding:0;text-decoration:underline;line-height:1}}aside,details,pre,progress{background-color:var(--accent-bg);border:1px solid var(--border);border-radius:var(--standard-border-radius);margin-bottom:1rem}aside{font-size:1rem;width:30%;padding:0 15px;margin-inline-start:15px;float:right}[dir=rtl] aside{float:left}@media only screen and (max-width:720px){aside{width:100%;float:none;margin-inline-start:0}}article,dialog,fieldset{border:1px solid var(--border);padding:1rem;border-radius:var(--standard-border-radius);margin-bottom:1rem}article h2:first-child,section h2:first-child{margin-top:1rem}section{border-top:1px solid var(--border);border-bottom:1px solid var(--border);padding:2rem 1rem;margin:3rem 0}section+section,section:first-child{border-top:0;padding-top:0}section:last-child{border-bottom:0;padding-bottom:0}details{padding:.7rem 1rem}summary{cursor:pointer;font-weight:700;padding:.7rem 1rem;margin:-.7rem -1rem;word-break:break-all}details[open]>summary+*{margin-top:0}details[open]>summary{margin-bottom:.5rem}details[open]>:last-child{margin-bottom:0}table{border-collapse:collapse;margin:1.5rem 0}figure>table{width:max-content}td,th{border:1px solid var(--border);text-align:start;padding:.5rem}th{background-color:var(--accent-bg);font-weight:700}tr:nth-child(even){background-color:var(--accent-bg)}table caption{font-weight:700;margin-bottom:.5rem}.button,button,input,select,textarea{font-size:inherit;font-family:inherit;padding:.5rem;margin-bottom:.5rem;border-radius:var(--standard-border-radius);box-shadow:none;max-width:100%;display:inline-block}input,select,textarea{color:var(--text);background-color:var(--bg);border:1px solid var(--border)}label{display:block}textarea:not([cols]){width:100%}select:not([multiple]){background-image:linear-gradient(45deg,transparent 49%,var(--text) 51%),linear-gradient(135deg,var(--text) 51%,transparent 49%);background-position:calc(100% - 15px),calc(100% - 10px);background-size:5px 5px,5px 5px;background-repeat:no-repeat;padding-inline-end:25px}[dir=rtl] select:not([multiple]){background-position:10px,15px}input[type=checkbox],input[type=radio]{vertical-align:middle;position:relative;width:min-content}input[type=checkbox]+label,input[type=radio]+label{display:inline-block}input[type=radio]{border-radius:100%}input[type=checkbox]:checked,input[type=radio]:checked{background-color:var(--accent)}input[type=checkbox]:checked::after{content:" ";width:.18em;height:.32em;border-radius:0;position:absolute;top:.05em;left:.17em;background-color:transparent;border-right:solid var(--bg) .08em;border-bottom:solid var(--bg) .08em;font-size:1.8em;transform:rotate(45deg)}input[type=radio]:checked::after{content:" ";width:.25em;height:.25em;border-radius:100%;position:absolute;top:.125em;background-color:var(--bg);left:.125em;font-size:32px}@media only screen and (max-width:720px){input,select,textarea{width:100%}}input[type=color]{height:2.5rem;padding:.2rem}input[type=file]{border:0}hr{border:none;height:1px;background:var(--border);margin:1rem auto}mark{padding:2px 5px;border-radius:var(--standard-border-radius);background-color:var(--marked);color:#000}mark a{color:#0d47a1}img,video{max-width:100%;height:auto;border-radius:var(--standard-border-radius)}figure{margin:0;display:block;overflow-x:auto}figcaption{text-align:center;font-size:.9rem;color:var(--text-light);margin-bottom:1rem}blockquote{margin-inline-start:2rem;margin-inline-end:0;margin-block:2rem;padding:.4rem .8rem;border-inline-start:.35rem solid var(--accent);color:var(--text-light);font-style:italic}cite{font-size:.9rem;color:var(--text-light);font-style:normal}dt{color:var(--text-light)}code,kbd,pre,pre span,samp{font-family:var(--mono-font);color:var(--code)}kbd{color:var(--preformatted);border:1px solid var(--preformatted);border-bottom:3px solid var(--preformatted);border-radius:var(--standard-border-radius);padding:.1rem .4rem}pre{padding:1rem 1.4rem;max-width:100%;overflow:auto;color:var(--preformatted)}pre code{color:var(--preformatted);background:0 0;margin:0;padding:0}progress{width:100%}progress:indeterminate{background-color:var(--accent-bg)}progress::-webkit-progress-bar{border-radius:var(--standard-border-radius);background-color:var(--accent-bg)}progress::-webkit-progress-value{border-radius:var(--standard-border-radius);background-color:var(--accent)}progress::-moz-progress-bar{border-radius:var(--standard-border-radius);background-color:var(--accent);transition-property:width;transition-duration:.3s}progress:indeterminate::-moz-progress-bar{background-color:var(--accent-bg)}dialog{max-width:40rem;margin:auto}dialog::backdrop{background-color:var(--bg);opacity:.8}@media only screen and (max-width:720px){dialog{max-width:100%;margin:auto 1em}}sub,sup{vertical-align:baseline;position:relative}sup{top:-.4em}sub{top:.3em}.notice{background:var(--accent-bg);border:2px solid var(--border);border-radius:var(--standard-border-radius);padding:1.5rem;margin:2rem 0}
        </style>
      </head>
      <body>
        <div class="head inner">
          <xsl:if test="/rss/channel/image">
            <a class="head_logo">
              <xsl:attribute name="href">
                <xsl:value-of select="/rss/channel/link"/>
              </xsl:attribute>
              <img>
                <xsl:attribute name="src">
                  <xsl:value-of select="/rss/channel/image/url"/>
                </xsl:attribute>
                <xsl:attribute name="title">
                  <xsl:value-of select="/rss/channel/title"/>
                </xsl:attribute>
              </img>
            </a>
          </xsl:if>
          <div class="head_main">
            <h1><xsl:value-of select="/rss/channel/title"/></h1>
            <p><xsl:value-of select="/rss/channel/description"/></p>
            <a class="head_link" target="_blank">
              <xsl:attribute name="href">
                <xsl:value-of select="/rss/channel/link"/>
              </xsl:attribute>
              Visit Website &#x2192;
            </a>
          </div>
        </div>
        <xsl:if test="/rss/channel/atom:link[@rel='alternate']">
          <div class="links inner">
            <xsl:for-each select="/rss/channel/atom:link[@rel='alternate']">
              <a target="_blank">
                <xsl:attribute name="class">
                  <xsl:value-of select="@icon"/>
                </xsl:attribute>
                <xsl:attribute name="href">
                  <xsl:value-of select="@href"/>
                </xsl:attribute>
                <xsl:value-of select="@title"/>
              </a>
            </xsl:for-each>
          </div>
        </xsl:if>
        <xsl:for-each select="/rss/channel/item">
          <div class="item inner">
            <h2>
              <a target="_blank">
                <xsl:attribute name="href">
                  <xsl:value-of select="link"/>
                </xsl:attribute>
                <xsl:value-of select="title"/>
              </a>
            </h2>
            <div class="item_meta">
              <span><xsl:value-of select="pubDate" /></span>
            </div>
          </div>
        </xsl:for-each>
        <nav class="footer">
          <ol>
            <li><a href="https://takashiidobe.com/">Back to site</a></li>
            <li><a href="https://takashiidobe.com/sitemap.xml">Sitemap</a></li>
            <li><a href="https://takashiidobe.com/resume">Resume</a></li>
            <li><a href="https://notes.takashiidobe.com">My Notes</a></li>
            <li><a href="https://links.takashiidobe.com">My Links</a></li>
          </ol>
        </nav>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
