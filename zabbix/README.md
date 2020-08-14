# Zabbix监控系统

标签（空格分隔）： 学习文档

---

#Zabbix监控
> zabbix是一个基于WEB界面的提供分布式系统监控及网络监视功能的企业级的开源解决方案。zabbix 能监视各种网络参数，保证服务器系统的安全运营；并提供灵活的通知机制以让系统管理员快速定位/解决存在的各种问题。
##Zabbix架构
###组件
1）Zabbinx Server:
> 负责接受 agent 发送的报告信息的核心组件，所有配置，统计数据及操作数据均由其组织进行；

2）Database Storage：
> 专用于存储所有配置信息，以及由zabbix 收集的数据；

3）Web interface：
> zabbix 的GUI接口，通常以Server运行在同一台主机上；

4）Proxy：
> 可选组件，常用于分布监控环境中，代理Server收集部分被监控端的监控数据，并同意发往Server端；

5）Agent；
> 部署在被监控主机上，负责收集本地数据并发往Server端或Proxy端；
###进程
> 默认情况下zabbix包含5个程序： zabbix_agentd，zabbix_get，zabbix_proxy，zabbix_sender，zabbix_server，另外一个zabbix_java_gateway是可选，需要另外安装。

1）zabbix_agentd
> 客户端的守护进程，此进程收集客户端数据，如cpu负载，内存，硬盘使用情况等。

2）zabbix_get
> zabbix工具，单独使用的命令，通常在server或proxy端执行获取远程客户端信息的命令。通常用户排错。例如在server端获取不到客户端的内存数据，我们可以用zabbix_get获取客户端的内容的方式来做故障排查。

3）zabbix_sender
> zabbix工具，用于发送数据给server或者proxy，通常用于耗时比较长的检查。很多检查非常耗时间，导致zabbix超时。于是我们在脚本执行完毕之后，使用sender主动提交数据。

4）zabbix_server
> zabbix服务端守护进程。zabbix_agentd,zabbix_get,zabbix_sender,zabbix_proxy,zabbix_java_gateway的数据最终都是提交到server
备注：当然不是都是主动，也可以是server主动去取数据。

5）zabbix_proxy
> zabbix代理守护进程。功能类似server，唯一不同的是它只是个中转站，他需要把收集到的数据提交或被提交到server里。

6）zabbix_java_gateway
> zabbix2.0之后引入的一个功能。顾名思义：Java网关，类似agentd，但是只用于Java方面，需要注意的是，它只能主动去获取数据，而不能被动获取数据，它的数据最终会给到server或者proxy。
###相关术语

* z主机（host）
> 要监控的网络设备，可由IP或DNS名称指定；

* 主机组（host group）
> 主机的逻辑容器，可以包含主机和模板，但同一个组织内的主机和模板不能互相链接；主机组通常在给用户或用户组指派监控权限时使用；

* 监控项（item）
> 一个特定监控指标的相关的数据：这些数据来自于被监控对象；item是zabbix进行数据收集的核心，相对某个监控对象，每个item都由“key”标识；

* 触发器（trigger）
> 一个表达式，用于评估某监控对象特定item内接收到的数据是否在合理范围内，也就是阈值；接受的数据量大于阈值时，触发器状态将从OK转变为Problem，当数据恢复到合理范围，又转变为OK。

* 事件（event）
> 触发一个值得关注的事情，比如触发器状态转变，新的agent或重新上线的agent的自动注册等；

* 动作（action）
> 指对于特定事件事先定义的处理方法，如发送通知，何时执行操作；

* 报警媒介类型（media）
> 发送通知的手段或渠道，如Email，Jabber或者SMS等：

* 模板（template）
> 用于快速定义被监控主机的预设条目集合，通常包含了item，trigger，graph，sreen，application以及low-level disvovery rule：模板可以直接链接到某个主机；

* 前端（frontend）
> Zabbix的web接口

##ZabbixServer的安装
所有安装所用的rpm包都在zabbix.tar.gz里，自定义yum本地仓库安装。
###一，搭建自定义yum仓库并安装支持包
```
[root@server rpm]# pwd
/root/rpm
[root@server rpm]# ls
fontconfig-2.8.0-5.el6.x86_64.rpm        libX11-common-1.6.4-3.el6.noarch.rpm
fontconfig-devel-2.8.0-5.el6.x86_64.rpm  libX11-devel-1.6.4-3.el6.x86_64.rpm
freetype-2.3.11-17.el6.x86_64.rpm        libXau-devel-1.0.6-4.el6.x86_64.rpm
freetype-devel-2.3.11-17.el6.x86_64.rpm  libxcb-1.12-4.el6.x86_64.rpm
gd-devel-2.0.35-11.el6.x86_64.rpm        libxcb-devel-1.12-4.el6.x86_64.rpm
libICE-1.0.6-1.el6.x86_64.rpm            libXext-1.3.3-1.el6.x86_64.rpm
libSM-1.2.1-2.el6.x86_64.rpm             libXpm-devel-3.5.10-2.el6.x86_64.rpm
libvpx-1.3.0-5.el6_5.x86_64.rpm          libXt-1.1.4-6.1.el6.x86_64.rpm
libvpx-devel-1.3.0-5.el6_5.x86_64.rpm    repodata
libX11-1.6.4-3.el6.x86_64.rpm            xorg-x11-proto-devel-7.7-14.el6.noarch.rpm
[root@server rpm]# cat /etc/yum.repos.d/yum.repo 
[xinjian]
name=xinjian
baseurl=file:///media/cdrom/
gpgcheck=0
enabled=1

[rpm]
name=rpm
baseurl=file:///root/rpm/
gpgcheck=0
enabled=1
[root@server rpm]# yum -y install createrepo
[root@server rpm]# createrepo -v .
[root@server rpm]# yum -y clean all
[root@server rpm]# yum makecache
[root@server rpm]# yum -y install pcre pcre-devel zlib-devel libaio libaio-devel libxml2 libxml2-devel bzip2-devel openssl openssl-devel net-snmp-devel net-snmp curl-devel gd gcc gcc-c++ make libjpeg-devel libpng-devel libcurl-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker mysql-devel net-snmp-utils
[root@server rpm]# yum -y install libvpx-devel gd-devel
```

###二，编译安装LNMP环境
安装nginx
```
[root@server rpm]# cd ..
[root@server ~]# useradd -s /sbin/nologin -M www
[root@server ~]# tar xf nginx-1.10.2.tar.gz -C /usr/src/
[root@server ~]# cd /usr/src/nginx-1.10.2/
[root@server nginx-1.10.2]# ./configure --prefix=/usr/local/nginx --user=www --group=www --with-http_stub_status_module --with-http_ssl_module && make && make install
[root@server nginx-1.10.2]# cd /usr/local/nginx/conf/
[root@server conf]# egrep -v "^$|#" nginx.conf.default > nginx.conf
[root@server conf]# cat nginx.conf
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen       80;
        server_name  localhost;
        location / {
            root   html;
            index  index.html index.htm;
        }
	location = /nginx-status {
          	    stub_status on;
		    access_log off;
        }
	location ~ \.php$ {
	fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
		include fastcgi_params;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
[root@k8smaster01 conf]# ln -sf /usr/local/nginx/sbin/nginx /usr/sbin/
[root@server conf]# nginx -t
nginx: the configuration file /usr/local/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/nginx/conf/nginx.conf test is successful
```

安装mysql

```
[root@server conf]# cd ~
[root@server ~]# tar xf mysql-5.5.32-linux2.6-x86_64.tar.gz -C /usr/local/
[root@server ~]# cd /usr/local/
[root@server local]# mv mysql-5.5.32-linux2.6-x86_64 mysql
[root@server local]# cd mysql/
[root@server mysql]# /bin/cp support-files/my-small.cnf /etc/my.cnf
[root@server mysql]# useradd -s /sbin/nologin -M mysql
[root@server mysql]# chown -R mysql.mysql data
[root@server mysql]# /usr/local/mysql/scripts/mysql_install_db --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data/ --user=mysql
[root@server mysql]# cp support-files/mysql.server /etc/init.d/mysqld
[root@server mysql]# chmod +x /etc/init.d/mysqld 
[root@server mysql]# /etc/init.d/mysqld start
Starting MySQL.. SUCCESS! 
[root@server mysql]# ss -antup | grep 3306
tcp    LISTEN     0      50                     *:3306                  *:*      users:(("mysqld",4140,10))
```

安装libmcrypt
```
[root@server mysql]# cd ~
[root@server ~]# tar xf libmcrypt-2.5.8.tar.gz -C /usr/src/
[root@server ~]# cd /usr/src/libmcrypt-2.5.8/
[root@server libmcrypt-2.5.8]# ./configure && make && make install
[root@server libmcrypt-2.5.8]# cd ~
```
安装GD
```
[root@server ~]# tar xf GD-2.18.tar.gz -C /usr/src/
[root@server ~]# cd /usr/src/GD-2.18/
[root@server GD-2.18]# perl Makefile.PL
[root@server GD-2.18]# make && make install
[root@server GD-2.18]# cd ~
```
安装PHP
```
[root@server ~]# tar xf php-5.6.30.tar.gz -C /usr/src/
cd [root@server ~]# cd /usr/src/php-5.6.30/
[root@server php-5.6.30]# ./configure --prefix=/usr/local/php --with-config-file-path=/usr/local/php/etc --with-bz2 --with-curl --enable-sockets --disable-ipv6 --with-gd --with-jpeg-dir=/usr/local --with-png-dir=/usr/local --with-freetype-dir=/usr/local --enable-gd-native-ttf --with-iconv-dir=/usr/local --enable-mbstring --enable-calendar --with-gettext --with-libxml-dir=/usr/local/ --with-zlib --with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd --with-mysql=mysqlnd --enable-dom --enable-xml --enable-fpm --with-libdir=lib64 --enable-bcmath
[root@server php-5.6.30]# make && make install
[root@server php-5.6.30]# cp php.ini-development /usr/local/php/etc/php.ini
[root@server php-5.6.30]# cd ~
#修改php.ini文件
[root@server ~]# cat -n /usr/local/php/etc/php.ini | sed -n '372p;382p;393p;660p;702p;820p;936p'
   372	max_execution_time = 300
   382	max_input_time = 300
   393	memory_limit = 256M
   660	post_max_size = 32M
   702	always_populate_raw_post_data = -1
   820	upload_max_filesize = 16M
   936	date.timezone = Asia/Shanghai
[root@server ~]# cd /usr/local/php/etc/
[root@server etc]# cp php-fpm.conf.default php-fpm.conf
#修改php-fpm配置文件，修改用户名为www
[root@server etc]# cat -n php-fpm.conf | sed -n '149p;150p'
   149	user = www
   150	group = www
```
###三，安装zabbix server端
编译安装
```
[root@server etc]# cd ~
[root@server ~]# useradd -s /sbin/nologin -M mysql
[root@server ~]# tar xf zabbix-3.2.4.tar.gz -C /usr/src/
[root@server ~]# cd /usr/src/zabbix-3.2.4/
[root@server zabbix-3.2.4]# ./configure --prefix=/usr/local/zabbix --with-mysql --with-net-snmp --with-libcurl --enable-server --enable-agent --enable-proxy --with-libxml2
[root@server zabbix-3.2.4]# make && make install
[root@server zabbix-3.2.4]# ln -s /usr/local/zabbix/sbin/* /usr/local/sbin/
[root@server zabbix-3.2.4]# ln -s /usr/local/zabbix/bin/* /usr/local/bin/
```

配置zabbix的mysql环境

```
[root@server zabbix-3.2.4]# cd ~
[root@server ~]# mysqladmin -uroot password '123123'
[root@server ~]# mysql -uroot -p123123 -e 'create database zabbix character set utf8;'
[root@server ~]# mysql -uroot -p123123 -e "grant all privileges on zabbix.* to zabbix@'localhost' identified by '123123';"
[root@server zabbix-3.2.4]# mysql -uroot -p123123 -e 'flush privileges;'
#将zabbix表导入到mysql zabbix库中，顺序不能错
[root@server zabbix-3.2.4]# mysql -uzabbix -p123123 zabbix < /usr/src/zabbix-3.2.4/database/mysql/schema.sql 
[root@server zabbix-3.2.4]# mysql -uzabbix -p123123 zabbix < /usr/src/zabbix-3.2.4/database/mysql/images.sql 
[root@server zabbix-3.2.4]# mysql -uzabbix -p123123 zabbix < /usr/src/zabbix-3.2.4/database/mysql/data.sql 
```

###安装Zabbix web GUI
复制zabbix web目录到nginx web根目录下
```
[root@server zabbix-3.2.4]# cp -rp /usr/src/zabbix-3.2.4/frontends/php  /usr/local/nginx/html/zabbix
[root@server zabbix-3.2.4]# cd /usr/local/nginx/html/
[root@server html]# ls
50x.html  index.html  zabbix
[root@server html]# chown -R www.www zabbix
[root@server html]# ll -d zabbix/
drwxr-xr-x. 13 www www 4096 2月  27 2017 zabbix/

```

启动nginx服务及php-fpm
```
[root@server html]# nginx
[root@server html]# /usr/local/php/sbin/php-fpm 
[root@server html]# netstat -antup | egrep "nginx|php-fpm"
tcp        0      0 0.0.0.0:80                  0.0.0.0:*                   LISTEN      23215/nginx         
tcp        0      0 127.0.0.1:9000              0.0.0.0:*                   LISTEN      23218/php-fpm       
```

登陆web根据提示生成zabbix.conf.php配置文件
```
#登陆webhttp://192.168.200.159/zabbix/setup.php 
[root@server html]# cd /usr/local/nginx/html/zabbix/conf
[root@server conf]# ls
maintenance.inc.php  zabbix.conf.php.example
#没有配置文件
[root@server conf]# ls
maintenance.inc.php  zabbix.conf.php  zabbix.conf.php.example
#登陆web后生成了配置文件
[root@server conf]# cat zabbix.conf.php
<?php
// Zabbix GUI configuration file.
global $DB;

$DB['TYPE']     = 'MYSQL';
$DB['SERVER']   = 'localhost';
$DB['PORT']     = '0';
$DB['DATABASE'] = 'zabbix';
$DB['USER']     = 'zabbix';
$DB['PASSWORD'] = '123123';

// Schema name. Used for IBM DB2 and PostgreSQL.
$DB['SCHEMA'] = '';

$ZBX_SERVER      = 'localhost';
$ZBX_SERVER_PORT = '10051';
$ZBX_SERVER_NAME = 'ZabbixServer';

$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
```
登陆zabbix web
设置zabbix中文模式
##zabbix server的配置

###zabbix_server.conf配置
```
[root@server conf]# cd /usr/local/zabbix/etc/
[root@server etc]# cat -n zabbix_server.conf | sed -n '12p;38p;87p;103p;111p;118p;136p;165p;181p;297p;447p'
    12	ListenPort=10051        #zabbix server监听端口
    38	LogFile=/tmp/zabbix_server.log   #zabbix server日志路径
    87	DBName=zabbix   #zabbix server连接MySQL数据库的数据库名
   103	DBUser=zabbix   #zabbix server连接MySQL数据库的用户名
   111	DBPassword=123123  #zabbix server连接MySQL数据库的密码
   118	DBSocket=/tmp/mysql.sock   #MySQL的实例文件位置
   136	StartPollers=5     #用于设置zabbix server服务启动时启动Pollers（主动收集数据进程）的数量，数量越多，则服务端吞吐能力越强，同时对系统资源消耗越大
   165	StartTrappers=10  #用于设置zabbix server服务启动时启动Trappers（负责处理Agentd推送过来的数据的进程）的数量。Agentd为主动模式时，zabbix server需要设置这个值大一些。
   181	StartDiscoverers=10   #用于设置zabbix server服务启动时启动Discoverers进程的数量，如果zabbix监控报Discoverers进程忙时，需要提高该值。
   297	ListenIP=0.0.0.0  #zabbix server启动的监听端口对那些ip开放，Agentd为主动模式时，这个值建议设置为0.0.0.0
   447	AlertScriptsPath=/usr/local/zabbix/share/zabbix/alertscripts #zabbix server运行脚本存放目录，一些供zabbix server使用的脚本，都可以放在这里。
```
###添加相关服务和端口到系统配置文件
```
[root@server etc]# vim /etc/services 
[root@server etc]# tail -4 /etc/services 
zabbix-agent    10050/tcp               # Zabbix Agent
zabbix-agent    10050/udp               # Zabbix Agent
zabbix-trapper  10050/tcp               # Zabbix Trapper
zabbix-trapper  10050/udp               # Zabbix Trapper

```
###添加管理维护脚本
```
[root@server etc]# cd ~
[root@server ~]# cp /usr/src/zabbix-3.2.4/misc/init.d/fedora/core/zabbix_server  /etc/init.d/zabbix_server
[root@server ~]# cd /etc/init.d/
[root@server init.d]# chmod +x /etc/init.d/zabbix_server 
[root@server init.d]# chkconfig zabbix_server on
[root@server init.d]# /etc/init.d/zabbix_server start
Starting zabbix_server:                                    [确定]
[root@server init.d]# ss -antup | grep zabbix_server
tcp    LISTEN     0      128                    *:10051                 *:*      users:(("zabbix_server",23617,4),("zabbix_server",23621,4),("zabbix_server",23622,4),("zabbix_server",23623,4),("zabbix_server",23624,4),("zabbix_server",23625,4),("zabbix_server",23626,4),("zabbix_server",23628,4),("zabbix_server",23629,4),("zabbix_server",23630,4),("zabbix_server",23631,4),("zabbix_server",23634,4),("zabbix_server",23635,4),("zabbix_server",23638,4),("zabbix_server",23639,4),("zabbix_server",23640,4),("zabbix_server",23644,4),("zabbix_server",23645,4),("zabbix_server",23648,4),("zabbix_server",23649,4),("zabbix_server",23651,4),("zabbix_server",23652,4),("zabbix_server",23653,4),("zabbix_server",23656,4),("zabbix_server",23657,4),("zabbix_server",23658,4),("zabbix_server",23662,4),("zabbix_server",23666,4),("zabbix_server",23667,4),("zabbix_server",23668,4),("zabbix_server",23670,4),("zabbix_server",23671,4),("zabbix_server",23672,4),("zabbix_server",23673,4),("zabbix_server",23674,4),("zabbix_server",23676,4),("zabbix_server",23677,4),("zabbix_server",23679,4),("zabbix_server",23680,4),("zabbix_server",23684,4),("zabbix_server",23685,4),("zabbix_server",23687,4))
```
###启动zabbix——server端进程
##zabbix_agent的安装与配置
```
[root@server ~]# wget http://repo.zabbix.com/zabbix/3.2/rhel/6/x86_64/zabbix-agent-3.2.4-1.el6.x86_64.rpm
[root@server ~]# rpm -ivh zabbix-agent-3.2.4-1.el6.x86_64.rpm
[root@server ~]# cd /etc/zabbix/
[root@server zabbix]# cat -n zabbix_agentd.conf | sed -n '13p;32p;95p;103p;120p;136p;147p;265p;284p'
    13	PidFile=/var/run/zabbix/zabbix_agentd.pid   #进程pid存放路径
    32	LogFile=/var/log/zabbix/zabbix_agentd.log   #zabbix agent日志存放路径
    95	Server=127.0.0.1,192.168.200.159   #指定zabbix server端IP地址
   103	ListenPort=10050      #指定agent监听端口
   120	StartAgents=3         #指定启动agentd进程数量。设置0表示关闭
   136	ServerActive=192.168.200.159:10051   #启用agentd主动模式，启动主动模式后，agentd将主动将收集到的数据发送到zabbix server端，Server Active后面指定的IP就是zabbix server端IP
   147	Hostname=192.168.200.159  #需要监控服务器的主机名或者IP地址，此选项的设置一定要和zabbix web端主机配置中杜英的主机名一致。
   265	Include=/etc/zabbix/zabbix_agentd.d/*.conf  #相关配置都可以放到此目录下，自动生效
   284	UnsafeUserParameters=1  #启用agent端之定义item功能，设置此参数为1后，就可以使用UserParameter指令了。UserParameter用于自定义item
```

##测试zabbix server监控
```
#利用下面命令测试
/usr/local/zabbix/bin/zabbix_get -s 192.168.200.159 -p 10050 -k "system.uptime"
-s 是指定zabbix agent端的IP地址
-p 是指定zabbix agent端的监听端口
-k 是监控项，即item
如果有输出结果，表示zabbix server可以从zabbix agent获取数据，配置成功。
```


#Zabbix  自定义监控mysql

##制作mysql免密登录

```
#创建监控用户
mysql监控用户创建
由于zabbix自带监控模板只能监控mysql的基本性能参数，只需建立一个USAGE权限或SELECT权限用户即可，登录主机限制为localhost：

GRANT USAGE ON *.* TO 'zabbixmonitor'@'localhost' IDENTIFIED BY 'passwd';
FLUSH PRIVILEGES;

[root@k8smaster01 scripts]# mysql_config_editor set --user=root --host=localhost --port=3306 --password -G zabbix
Enter password:      --输入密码   会在家目录下生成一个.mylogin.cnf文件
[root@k8smaster01 scripts]# file /root/.mylogin.cnf
/root/.mylogin.cnf: data
[root@k8smaster01 scripts]# mysql_config_editor print --all
[zabbix]
user = root
password = *****
host = localhost
port = 3306
进行免密登录验证
[root@k8smaster01 scripts]# mysqladmin  --login-path=zabbix status
Uptime: 4121  Threads: 1  Questions: 15  Slow queries: 0  Opens: 105  Flush tables: 1  Open tables: 98  Queries per second avg: 0.003

```

##编写自定义监控脚本

```
[root@k8smaster01 ~]# mkdir -p /server/scripts
[root@k8smaster01 ~]# cd /server/scripts/
[root@k8smaster01 scripts]# vim check_mysql.sh
[root@k8smaster01 scripts]# cat check_mysql.sh 
#!/bin/bash
# author:Mr.cheng

MySQL_USER="root"
MySQL_PWD="********"
MySQL_HOST="localhost"
MySQL_PORT="3306"

MySQL_CONN="/usr/bin/mysqladmin -u${MySQL_USER} -h${MySQL_HOST} -P${MySQL_PORT} -p${MySQL_PWD}"
#MySQL_CONN="/usr/bin/mysqladmin --login-path=zabbix"


if [ $# -ne "1" ];then
    echo "arg error!"
fi

case $1 in
    Uptime)
        result=`${MySQL_CONN} status 2>/dev/null | cut -f2 -d":" | cut -f1 -d "T"`
        echo $result
        ;;
    Com_update)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Com_update" | cut -d"|" -f3`
        echo $result
        ;;
    Slow_querles)
        result=`${MySQL_CONN} status 2>/dev/null | cut -f5 -d":" | cut -f1 -d"O"`
        echo $result
        ;;
    Com_select)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Com_select" | cut -d "|" -f3`
        echo $result
        ;;
    Com_rollback)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Com_rollback" | cut -d"|" -f3`
        echo $result
        ;;
    Questions)
        result=`${MySQL_CONN} status 2>/dev/null | cut -f4 -d":" | cut -f1 -d"S"`
        echo $result
        ;;
    Com_insert)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Com_insert" | cut -d"|" -f3`
        echo $result
        ;;
    Com_delete)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Com_delete" | cut -d"|" -f3`
        echo $result
        ;;
    Com_commit)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Com_commit" | cut -d"|" -f3`
        echo $result
        ;;
    Bytes_sent)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Bytes_sent" | cut -d"|" -f3`
        echo $result
        ;;
    Bytes_received)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Bytes_received" | cut -d"|" -f3`
        echo $result
        ;;
    Com_begin)
        result=`${MySQL_CONN} extended-status 2>/dev/null | grep -w "Com_begin" | cut -d"|" -f3`
        echo $result
        ;;
    *)
        echo "Usage:$0(Uptime|Com_update|Slow_querles|Com_rollback|Questions|Com_insert|Com_delete|Com_commit|Bytes_sent|Bytes_received|Com_begin)"
        ;;
esac

#进行脚本测试
[root@k8smaster01 scripts]# sh check_mysql.sh Uptime
4523
[root@k8smaster01 scripts]# chmod +x check_mysql.sh 
[root@k8smaster01 scripts]# chown zabbix.zabbix check_mysql.sh
```

##在zabbix-agent端创建自定义键值配置文件
```
#创建mysql.status的键值
[root@k8smaster01 scripts]# cd /etc/zabbix/zabbix_agentd.d/
[root@k8smaster01 zabbix_agentd.d]# vim mysql_status.conf 
[root@k8smaster01 zabbix_agentd.d]# cat mysql_status.conf 
UserParameter=mysql.status[*],/server/scripts/check_mysql.sh $1
#删除旧键值模版
[root@k8smaster01 zabbix_agentd.d]# rm -rf userparameter_mysql.conf
#创建mysql.ping和mysql.version的键值
[root@k8smaster01 zabbix_agentd.d]# cat mysql_status.conf 
UserParameter=mysql.status[*],/server/scripts/check_mysql.sh $1
UserParameter=mysql.ping,/usr/bin/mysqladmin -uroot -p123123 ping | grep -c alive
UserParameter=mysql.version,/usr/bin/mysql -V
#重启zabbix-agentd服务
[root@k8smaster01 zabbix_agentd.d]# systemctl restart zabbix-agent

```


```
```




