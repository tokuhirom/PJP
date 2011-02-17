+{
	DB => [
		'dbi:SQLite:dbname=/usr/local/webapp/PJP/db/pjp.db',
		'',
		'',
	],
    'Text::Xslate' => {
        path => ['tmpl/'],
        cache_dir => '/tmp/pjp-xslate.cache/'
    },
};
