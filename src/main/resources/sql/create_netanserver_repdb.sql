create table network_analytics_feature(
	feature_name char(100) not null,
	product_id char(50) not null,
	release char(10) not null,
	rstate char(10) not null,
	build char(10) not null,
	install_date timestamp default CURRENT_TIMESTAMP,
	status char(10) not null,
	library_path char(100) null,
	primary key (product_id, build, install_date)
); 

create table network_analytics_platform(
	product_id char(30) not null,
	product_name char(100) not null,
	release char(10) not null,
	rstate char(10) not null,
	build char(10) not null,
	install_date timestamp default CURRENT_TIMESTAMP,
    status char(10) not null,
	primary key (product_id, build, install_date)
);

create table concurrent_users(
	timestamp char(100) not null,
	analyst char(10) not null,
	author char(10) not null,
	consumer char(10) not null,
	other char(10) not null,
	total char(10) not null,
	primary key (timestamp,total)
);

create table defined_users(
	timestamp char(100) not null,
	analyst char(10) not null,
	author char(10) not null,
	consumer char(10) not null,
	other char(10) not null,
	total char(10) not null,
	primary key (timestamp,total)
);

alter database netanserver_repdb owner to netanserver;
alter user netanserver with superuser;