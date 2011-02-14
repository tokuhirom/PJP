create table func (
    name varchar(255) not null primary key,
    version varchar(255) not null,
    html text
);

create table pod (
	package     varchar(255) not null,
	description varchar(255),
	path        varchar(255) not null PRIMARY KEY,
	distvname   varchar(255) not null,
    repository  varchar(255) not null,
	html        text
);
CREAte INDEX if not exists package on pod (package);
CREAte INDEX if not exists distvname on pod (distvname);

