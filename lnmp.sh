#! /bin/bash

# usage: ./lnmp.sh nginx

# notice: softwave should in /data/soft  
# softwave version:
# CentOS release 6.5 (Final) ,mysql-5.6.21,nginx-1.7.9,php-5.6.3
# updata change by yibu,data:2017-04-14 17:05 && Mon May 8 15:19:35 CST 2017

# mysql
# if command not found ,need ln -s bin/mysql /usr/bin
# eg. ln -s /data/mysql/bin/mysql /usr/bin
# maybe should cat my.cnf > /etc/my.conf  by hands again.

mysql_install () {
                yum install cmake -y
                wget -P $soft http://downloads.vikduo.com/${mysql_version}
                wait
                cd $soft
                cat ./my.cnf > /etc/my.cnf 
				groupadd -r mysql
                useradd -g mysql -r -s /sbin/nologin mysql
                mkdir -p ${mysql_path}
                chown -R mysql:mysql ${mysql_path}
                tar xzf ${mysql_version}
                install_directory=`echo ${mysql_version} | sed -e 's/.tar.gz//g'`
                cd ${install_directory}
                cmake . -DCMAKE_INSTALL_PREFIX=${mysql_path} \
                -DMYSQL_DATADIR=${mysqlData_path} \
                -DSYSCONFDIR=/etc \
                -DWITH_INNOBASE_STORAGE_ENGINE=1 \
                -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
                -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
                -DWITH_READLINE=1 \
                -DWITH_SSL=bundled \
                -DWITH_ZLIB=bundled \
                -DWITH_LIBWRAP=0 \
                -DMYSQL_UNIX_ADDR=${mysql_sock} \
                -DDEFAULT_CHARSET=utf8 \
                -DDEFAULT_COLLATION=utf8_general_ci
                test $? != 0 && echo "mysql_configure error" && exit
                make
                test $? != 0 && echo "mysql_make error" && exit
                make install
                test $? != 0 && echo "mysql make install error" && exit
                cp support-files/mysql.server /etc/init.d/mysqld
                chmod +x /etc/init.d/mysqld
                chkconfig --add mysqld
                chkconfig mysqld on
                echo 'MANPATH /data/mysql/man' >> /etc/man.config
                echo '/data/mysql/lib/' > /etc/ld.so.conf.d/mysql.conf
                ldconfig
                ln -sv ${mysql_path}/include/ /usr/include/mysql
                ${mysql_path}/scripts/mysql_install_db --basedir=${mysql_path} --datadir=${mysqlData_path} --user=mysql
                rm -f ${mysql_path}/my.cnf
                mkdir ${mysql_path}/log
                chown mysql:mysql ${mysql_path}/log
                ln -s /data/mysql/bin/mysql /usr/bin
				service mysqld start
                test "$(netstat -ntlp | grep mysql)" == "" && echo "Start Mysql failed" || echo "Start Mysql OK"
                echo "export PATH=\$PATH:${mysql_path}/bin" > /etc/profile.d/mysql.sh
                . /etc/profile.d/mysql.sh
                #add zabbix monitor user
                #mysql -e"grant SELECT,REPLICATION CLIENT on *.* to 'zabbix'@'localhost' identified by '2Zstumd2Amzi';"
}

nginx_install () {
                yum install pcre pcre-devel -y
                #wget -P ${soft} http://downloads.vikduo.com/${nginx_version}
                wait
                cd ${soft}
                groupadd nginx
                useradd -g nginx nginx -s /sbin/nologin
                tar xzf ${nginx_version}
                install_directory=`echo ${nginx_version} | sed -e 's/.tar.gz//g'`
                cd ${install_directory}
                ./configure --prefix=${nginx_path} --with-cc-opt=-O3 --user=nginx --group=nginx --with-cpu-opt=intel --with-http_stub_status_module --with-http_ssl_module --with-http_realip_module
                test $? != 0 && echo "nginx_configure error" && exit
                make
                test $? != 0 && echo "nginx_make error" && exit
                make install
                test $? != 0 && echo "nginx make install error" && exit
cat > /etc/init.d/nginxd << EOF
#!/bin/bash
#
# nginx - this script starts and stops the nginx daemin
#
# chkconfig:   - 85 15
# description:  Nginx is an HTTP(S) server, HTTP(S) reverse \
#               proxy and IMAP/POP3 proxy server
# processname: nginx
. /etc/rc.d/init.d/functions

# Source networking configuration.

. /etc/sysconfig/network

# Check that networking is up.

[ "\$NETWORKING" = "no" ] && exit 0

nginx="${nginx_path}/sbin/nginx"

prog=\$(basename \$nginx)

NGINX_CONF_FILE="${nginx_path}/conf/nginx.conf"

[ -f /etc/sysconfig/nginx ] && . /etc/sysconfig/nginx

lockfile=/var/lock/subsys/nginx

make_dirs() {

   # make required directories

   user=`nginx -V 2>&1 | grep "configure arguments:" | sed 's/[^*]*--user=\([^ ]*\).*/\1/g' -`

   options=`\$nginx -V 2>&1 | grep 'configure arguments:'`

   for opt in \$options; do

       if [ `echo \$opt | grep '.*-temp-path'` ]; then

           value=`echo \$opt | cut -d "=" -f 2`

           if [ ! -d "\$value" ]; then

               # echo "creating" \$value

               mkdir -p \$value && chown -R \$user \$value

           fi

       fi

   done

}

start() {

    [ -x \$nginx ] || exit 5

    [ -f \$NGINX_CONF_FILE ] || exit 6

    make_dirs

    echo -n $"Starting \$prog: "

    daemon \$nginx

    retval=\$?

    echo

    [ \$retval -eq 0 ] && touch \$lockfile

    return \$retval

}

stop() {

    echo -n $"Stopping \$prog: "

    killproc \$prog -QUIT

    retval=\$?

    echo

    [ \$retval -eq 0 ] && rm -f \$lockfile

    return \$retval

}

restart() {

    configtest || return \$?

    stop

    sleep 1

    start

}

reload() {

    configtest || return \$?

    echo -n $"Reloading \$prog: "

    killproc \$nginx -HUP

    RETVAL=\$?

    echo

}

force_reload() {

    restart

}

configtest() {

  \$nginx -t -c \$NGINX_CONF_FILE

}

rh_status() {

    status \$prog

}

rh_status_q() {

    rh_status >/dev/null 2>&1

}

case "\$1" in

    start)

        rh_status_q && exit 0

        \$1

        ;;

    stop)

        rh_status_q || exit 0

        \$1

        ;;

    restart|configtest)

        \$1

        ;;

    reload)

        rh_status_q || exit 7

        \$1

        ;;

    force-reload)

        force_reload

        ;;

    status)

        rh_status

        ;;

    condrestart|try-restart)

        rh_status_q || exit 0

            ;;

    *)

        echo $"Usage: \$0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"

        exit 2

esac
EOF
                chmod 755 /etc/init.d/nginxd
                chkconfig --add nginxd
                chkconfig nginxd on
                mkdir ${nginx_path}/conf/vhost
                cd ${nginx_path}/conf
                wget -O nginx.conf http://downloads.vikduo.com/NginxConf/nginx.conf
                wget -P ${nginx_path}/conf/vhost http://downloads.vikduo.com/NginxConf/default.conf
                wget -P ${nginx_path}/conf/vhost http://downloads.vikduo.com/NginxConf/demo.vikduo.com.conf
                #add zabbix monitor nginx status 
                wget -P ${nginx_path}/conf/vhost http://downloads.vikduo.com/zabbix/nginx-status.conf
                /etc/init.d/nginxd start
                test "$(netstat -ntlp | grep nginx)" == "" && echo "Start Nginx failed" || echo "Start Nginx OK"
                echo "export PATH=\$PATH:${nginx_path}/sbin" > /etc/profile.d/nginx.sh
                . /etc/profile.d/nginx.sh
}

php_install () {
                yum install libxml2-devel bzip2-devel libcurl-devel libjpeg-devel libpng-devel freetype-devel -y
                wget -P ${soft}
				http://downloads.vikduo.com/${php_version}
                wget -P ${soft} http://downloads.vikduo.com/libmcrypt-2.5.8.tar.gz
                wait
                cd ${soft}
                tar xzf libmcrypt-2.5.8.tar.gz
                cd libmcrypt-2.5.8
                ./configure  --prefix=${libmcrypt_path}
                make && make install
                cd ..
                tar xzf ${php_version}
                install_directory=`echo ${php_version} | sed -e 's/.tar.gz//g'`
                cd ${install_directory}
                ./configure  --prefix=${php_path} --with-mysql=mysqlnd --with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd --with-openssl --enable-mbstring --with-freetype-dir --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --enable-sockets --enable-fpm --with-mcrypt=${libmcrypt_path} --with-config-file-path=/etc --with-config-file-scan-dir=/etc/php.d --with-bz2 --with-gd --with-curl --enable-zip --enable-soap
                test $? != 0 && echo "PHP_configure error" && exit
                make
                test $? != 0 && echo "php_make error" && exit
                make install
                test $? != 0 && echo "php_make install error" && exit
                cp ${soft}/${install_directory}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
                chmod 755 /etc/init.d/php-fpm
                chkconfig --add php-fpm
                chkconfig php-fpm on
                ln -s /etc/php-fpm.conf ${php_path}/etc/php-fpm.conf
                wget -P /etc http://downloads.vikduo.com/PhpConf/php.ini
                wget -P /etc http://downloads.vikduo.com/PhpConf/php-fpm.conf
                mkdir ${php_path}/log ; chown nginx:nginx ${php_path}/log
                /etc/init.d/php-fpm start
                test "$(netstat -ntlp | grep php-fpm)" == "" && echo "Start Php failed" || echo "Start Php OK"
                echo "export PATH=\$PATH:${php_path}/bin" > /etc/profile.d/php.sh
                . /etc/profile.d/php.sh
}

memcached_install () {
                wget -P ${soft} http://downloads.vikduo.com/memcached-1.4.33.tar.gz
                wait
				cd ${soft}
                tar xzf memcached-1.4.33.tar.gz
                cd memcached-1.4.33
                ./configure --prefix=${memcached_path} --with-libevent=${libevent_path}
                make && make install
                ${memcached_path}/bin/memcached -d -m 1024 -u root -p 11211 -c 256 -P /tmp/memcached.pid
                mkdir -p /data/memcached/bin/memcached  
				echo "${memcached_path}/bin/memcached -d -m 1024 -u root -p 11211 -c 2048 -P /tmp/memcached.pid" >> /etc/rc.local
}

memcache_install () {
                wget -P ${soft} http://downloads.vikduo.com/memcache-2.2.7.tgz
                wait
                cd ${soft}
                tar xzf memcache-2.2.7.tgz
                cd memcache-2.2.7
                ${php_path}/bin/phpize
                ./configure --enable-memcache --with-php-config=${php_path}/bin/php-config --with-zlib-dir
                make && make install
                sed -i '865i\extension=memcache.so' /etc/php.ini
                service php-fpm restart
}

libevent_install () {
                wget -P ${soft} http://downloads.vikduo.com/libevent-2.0.21-stable.tar.gz
                wait
                cd ${soft}
                tar xzf libevent-2.0.21-stable.tar.gz
                cd libevent-2.0.21-stable
                ./configure --prefix=${libevent_path}
                make && make install
}

librdkafka_install () {
                wget -P ${soft} http://downloads.vikduo.com/librdkafka-master.zip
                wait
                cd ${soft}
                unzip librdkafka-master.zip
                cd librdkafka-master
                ./configure --prefix=/data/librdkafka-master
                make && make install
}

Consul_install () {
                wget -P ${soft} http://downloads.vikduo.com/consul_0.7.2_linux_amd64.zip
                wget -P /etc/init.d/ http://downloads.vikduo.com/consuld
                wait
                cd ${soft}
                unzip consul_0.7.2_linux_amd64.zip
                mv consul /usr/local/sbin/
                chmod 755 /usr/local/sbin/consul
                mkdir -p /data/consul/data
                mkdir /data/consul/etc
                mkdir /data/consul/logs
                chmod 755 /etc/init.d/consuld
                chkconfig --add consuld
                chkconfig consuld on
}

Thrift_install () {
                thriftSoft="${soft}/thrift"
                autoconf_version="autoconf-2.69.tar.gz"
                automake_version="automake-1.14.tar.gz"
                bison_version="bison-2.5.1.tar.gz"
                thrift_version="thrift-0.9.3.tar.gz"
                thriftInstallPath="/data/thrift"
                test ! -d ${thriftSoft} && mkdir ${thriftSoft}
                cd ${thriftSoft}
                yum -y groupinstall "Development Tools"
#####安装autoconf
                wget -P ${thriftSoft} http://downloads.vikduo.com/thrift/${autoconf_version}
                tar xzf ${autoconf_version}
                source_dir=`echo ${autoconf_version} | sed -e 's/.tar.gz//g'`
                cd ${source_dir}
                ./configure --prefix=/usr
                make
                make install
                cd ..
#####安装automake
                wget -P ${thriftSoft} http://downloads.vikduo.com/thrift/${automake_version}
                tar xzf ${automake_version}
                source_dir=`echo ${automake_version} | sed -e 's/.tar.gz//g'`
                cd ${source_dir}
                ./configure --prefix=/usr
                make
                make install
                cd ..
#####安装bison
                wget -P ${thriftSoft} http://downloads.vikduo.com/thrift/${bison_version}
                tar xzf ${bison_version}
                source_dir=`echo ${bison_version} | sed -e 's/.tar.gz//g'`
                cd ${source_dir}
                ./configure --prefix=/usr
                make
                make install
                cd ..
# 添加可选的C++语言库的依赖性
#               yum -y install libevent-devel zlib-devel openssl-devel
#               tar xvf boost_1_53_0.tar.gz
#               cd boost_1_53_0
#               ./bootstrap.sh
#               ./b2 install
#               cd ..
#####安装thrift
                source /etc/profile.d/php.sh
                wget -P ${thriftSoft} http://downloads.vikduo.com/thrift/${thrift_version}
                tar xzf ${thrift_version}
                source_dir=`echo ${thrift_version} | sed -e 's/.tar.gz//g'`
                cd ${source_dir}
                ./configure --prefix=${thriftInstallPath} --with-php=yes --with-cpp=no --with-lua=no
                make
                make install
                echo "export PATH=${thriftInstallPath}/bin:\$PATH" >> /etc/profile.d/thrift.sh
                source /etc/profile.d/thrift.sh
}

zabbix_install () {
                host=`/sbin/ifconfig eth0 | sed -n '/inet /{s/.*addr://;s/ .*//;p}'`
                name=`hostname`
                zabbix_server_ip="10.104.235.153"
                cd ${soft}
                wget http://downloads.vikduo.com/zabbix/${zabbix_version}.tar.gz
                tar zxf ${zabbix_version}.tar.gz
                cd ${zabbix_version}
                ./configure --prefix=${zabbix_path} --enable-agent
                make && make install
                test $? != 0 && echo "zabbix install is error" && exit || echo "zabbix install is ok"
                cp ${soft}/${zabbix_version}/misc/init.d/fedora/core/zabbix_agentd /etc/init.d/
                sed -i "s#/usr/local#${zabbix_path}#g" /etc/init.d/zabbix_agentd
                sed -i "s#/tmp/zabbix_agentd.log#${zabbix_path}/log/zabbix_agentd.log#g" ${zabbix_path}/etc/zabbix_agentd.conf
                sed -i "s/ServerActive\=127.0.0.1/ServerActive=${zabbix_server_ip}/g" ${zabbix_path}/etc/zabbix_agentd.conf
                sed -i "s/Server\=127.0.0.1/Server=${zabbix_server_ip}/g" ${zabbix_path}/etc/zabbix_agentd.conf
                sed -i "s/Hostname\=Zabbix server/Hostname=$name/g" ${zabbix_path}/etc/zabbix_agentd.conf 
                sed -i 's/# UnsafeUserParameters=0/UnsafeUserParameters=1/g' ${zabbix_path}/etc/zabbix_agentd.conf
                sed -i /"# Include=$"/a\Include=${zabbix_path}/etc/zabbix_agentd.conf.d/ ${zabbix_path}/etc/zabbix_agentd.conf
                wget -P ${zabbix_path}/etc/zabbix_agentd.conf.d/ http://downloads.vikduo.com/zabbix/UserParameter.conf
                wget -P ${zabbix_path}/bin/ http://downloads.vikduo.com/zabbix/checkmysqlperformance.sh
                wget -P ${zabbix_path}/bin/ http://downloads.vikduo.com/zabbix/nginx_status.sh
                chmod +x ${zabbix_path}/bin/*.sh
                mkdir ${zabbix_path}/log
                chown zabbix.zabbix -R /data/zabbix
                iptables  -I INPUT -s ${zabbix_server_ip} -p tcp -m state --state NEW -m tcp --dport 10050 -j ACCEPT
                iptables-save > /etc/sysconfig/iptables
                /etc/init.d/zabbix_agentd start
                test "$(netstat -ntlp | grep 10050)" == "" && echo "Start Zabbix_agentd failed" || echo "Start Zabbix_agentd OK"
                chkconfig zabbix_agentd on
}

rabbitmq_install () {
                #install dependent environment
		yum install build-essential openssl openssl-devel unixODBC unixODBC-devel make gcc gcc-c++ kernel-devel m4 ncurses-devel tk tcl -y
		#install erlang server
		if [ ! -d ${erlang_path} ];then
		   cd ${soft}
		   wget http://downloads.vikduo.com/rabbitmq/${erlang_version}.tar.gz
		   wait && /bin/tar -zxf ${erlang_version}.tar.gz
		   cd ${soft}/${erlang_version}
		   ./configure --prefix=${erlang_path} --enable-hipe --enable-threads --enable-smp-support --enable-kernel-poll --without-javac
		   test $? != 0 && echo "mysql_configure error" && exit
		   make  && make install
		   if [ $? == 0 ];then
		      echo -e "\033[32merlang install successfully!\033[0m"
		   else
		      echo -e "\033[32merlang install is fail!\033[0m"
		      exit 1
		   fi
		   rm -rf ${soft}/${erlang_version}
		else
		   echo -e "\033[31merlang directory already exists!\033[0m"
		   :
		fi
		#install rabbitmq server
		if [ ! -d ${rabbitmq_path} ];then
		   cd ${soft}
		   wget http://downloads.vikduo.com/rabbitmq/${rabbitmq_version}
		   wait && /bin/tar -zxf ${rabbitmq_version}
		   mv rabbitmq_server-3.6.6 ${rabbitmq_path}
		   if [ -d ${rabbitmq_path} ];then
		      echo -e "\033[32mrabbitmq_server install successfully!\033[0m"
		   else
		      echo -e "\033[31mrabbitmq_server install fail!\033[0m"
		      exit 1
		   fi
		   echo "export PATH=\$PATH:${rabbitmq_path}/sbin:${erlang_path}/bin" > /etc/profile.d/rabbitmq.sh
		   . /etc/profile.d/rabbitmq.sh
		   cd ${rabbitmq_path}
		   nohup rabbitmq-server start &
		   if [ $? == 0 ];then
		      echo -e "\033[32mrabbitmq_server startup successfully!\033[0m"
		      if ! grep -q 15672 /etc/sysconfig/iptables;then
			 sed -i '/INPUT -j REJECT/i\-A INPUT -m state --state NEW -m tcp -p tcp -m multiport --dports 15672,25672,4369 -j ACCEPT' /etc/sysconfig/iptables
			 service iptables restart
		      fi
		      sleep 5
		      rabbitmq-plugins enable rabbitmq_management
		      value=true
		      while $value
		      do
		      if ! netstat -nltp|grep -q 15672 ;then
			  echo -e "\033[31menable rabbitmq_management fail, restarting...\033[0m"
			  rabbitmq-plugins enable rabbitmq_management
		      else
			  value=false
		      fi
		      done
		      echo -e "\033[32menable rabbitmq_management ok\033[0m"

		   fi
		else
		   echo -e "\033[31mrabbitmq directory already exists!\033[0m"
		   exit 1
		fi
		#install rabbitmq_delayed_message_exchange plugins
		if [ ! -f ${rabbitmq_path}/plugins/rabbitmq_delayed_message_exchange-0.0.1.ez ];then
		    wget -P ${rabbitmq_path}/plugins/ http://downloads.vikduo.com/rabbitmq/rabbitmq_delayed_message_exchange-0.0.1.ez
		fi
		sleep 1
		rabbitmq-plugins enable rabbitmq_delayed_message_exchange
		test $? != 0 && echo -e "\033[31menable rabbitmq_delayed_message_exchange fail\033[0m" && exit || echo -e "\033[32menable rabbitmq_delayed_message_exchange ok\033[0m" 
}

install_path="/data"
soft="${install_path}/soft"
mysql_path="${install_path}/mysql"
mysql_sock="/tmp/mysql.sock"
mysqlData_path="${install_path}/mysql/data"
mysql_version="mysql-5.6.21.tar.gz"
nginx_path="${install_path}/nginx"
# nginx_version="nginx-1.7.9.tar.gz"
nginx_version="nginx-1.12.0.tar.gz"
php_path="${install_path}/php"
# php_version="php-5.6.3.tar.gz"
php_version="php-7.1.4.tar.gz"
libmcrypt_path="${install_path}/libmcrypt"
memcached_path="${install_path}/memcached"
libevent_path="${install_path}/libevent"
zabbix_path="${install_path}/zabbix"
zabbix_version="zabbix-2.4.5"
rabbitmq_path="${install_path}/rabbitmq_server"
rabbitmq_version="rabbitmq-server-generic-unix-3.6.6.tar.gz"
erlang_path="${install_path}/erlang"
erlang_version="otp_src_19.2"

yum install zlib zlib-devel wget gcc gcc-c++ make autoconf gcc gcc-c++ openssl openssl-devel ncurses ncurses-devel -y
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

mkdir -p /data/soft
yum install -y dos2unix 
dos2unix lnmp.sh 
chmod +x lnmp.sh 

# 线上环境
# echo "10.204.208.92             downloads.vikduo.com" >> /etc/hosts
# 测试、开发环境
# echo "10.100.100.31            downloads.vikduo.com" >> /etc/hosts

case $1 in
        "mysql" )
                mysql_install
        ;;
        "nginx" )
                nginx_install
        ;;
        "php" )
                php_install
        ;;
        "nginx+php" )
                nginx_install
                php_install
        ;;
        "lnmp" )
                mysql_install
                nginx_install
                php_install
        ;;
        "memcached" )
                libevent_install
                memcached_install
        ;;
        "memcache" )
                memcache_install
        ;;
        "thrift" )
                Thrift_install
        ;;
        "opt" )
                libevent_install
                librdkafka_install
                Consul_install
                Thrift_install
        ;;
        "zabbix" )
                zabbix_install
        ;;
        "rabbitmq" )
                rabbitmq_install
        ;;
        *)
                echo "Usage: $0 {mysql|nginx|php|nginx+php|memcache|lnmp|memcached|thrift|opt|zabbix|rabbitmq}"
        ;;
esac
