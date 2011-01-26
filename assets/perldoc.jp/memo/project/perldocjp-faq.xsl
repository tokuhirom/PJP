<?xml version="1.0" encoding="EUC-JP"?>

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="EUC-JP"
    doctype-public="-//W3C//DTD HTML 4.01//EN"/>

  <xsl:template match="/faqlist">
    <html lang="ja">
      <head>
        <title>FAQ - Japanize Perl Resours Project</title>
        <link rel="stylesheet" type="text/css" href="faq.css" />
        <link rel="stylesheet" type="text/css" href="index.css" />
      </head>
      <body>

        <div class="menu">
          <ul>
            <li><a href="index.html">Home</a></li>
            <li><a href="joinus.html">参加するには?</a>(<a href="joinus.html#ml">メーリングリスト</a>)</li>
            <li><a href="translation.html">翻訳の入手</a></li>
            <li><a href="event.html">イベント</a></li>
            <li class="current">FAQ</li>
            <li><a href="link.html">リンク</a></li>
            <li class="sourceforge"><a href="http://sourceforge.jp/projects/perldocjp/">sourcefoge site</a></li>
          </ul>
        </div>

        <h1>FAQ</h1>

        <h2>インデックス</h2>
        <xsl:for-each select="section">
          <ul>
            <li><xsl:value-of select="title" />
              <ul>
                <xsl:for-each select="faq/part">
                  <li>
                    <xsl:element name="a">
                      <xsl:if test="@id">
                        <xsl:attribute name="href">
                          #<xsl:value-of select="@id"/>
                        </xsl:attribute>
                      </xsl:if>
                      Q. 
                      <xsl:value-of select="question"/>
                    </xsl:element>
                  </li>
                </xsl:for-each>
              </ul>
            </li>
          </ul>
        </xsl:for-each>

        <xsl:for-each select="section">  
          <h2><xsl:value-of select="title"/></h2>
          <dl>
            <xsl:for-each select="faq/part">
              <xsl:element name="dt">
                <xsl:if test="@id">
                  <xsl:attribute name="id">
                    <xsl:value-of select="@id"/>
                  </xsl:attribute>
                </xsl:if>
                Q. 
                <xsl:value-of select="question"/>
              </xsl:element>
              <dd>
                <xsl:for-each select="answer">
                  <p>
                    A.
                    <xsl:copy-of select="@*|*|text()"/>
                  </p>
                </xsl:for-each>
              </dd>
            </xsl:for-each>
          </dl>
        </xsl:for-each>

        <div class="footer">
          <address>
            <a href="http://sourceforge.jp/projects/perldocjp/">Japanize Perl Resources Project</a>
          </address>
        </div>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>

