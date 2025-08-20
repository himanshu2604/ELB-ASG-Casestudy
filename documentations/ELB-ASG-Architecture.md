25)AWSCLOUDUS-EAST-1

|BoAUTOSCALING| r alt,MONITORINGANDSCALING

GROUP

(=— $=

Ex: .. .. .. . oo .......LLL ~ 77SCALINGes

.... = >)

AutoScaling )i |! {FBAVAILABILITYZONE18 “Ss NV

Group |

belMin:20, u1 a PRIVATESUBNET2 coalsie coat)In

sired: ...h metrics. Cm — ss custom CPU‘olicyetree

j a .... instancesAdd2 Removeinstance1 \ . ; Il pusuiceuener2 CloudWatchCloudWatch

.......... ..... ............ alowtraffio——————————————————————— Ec2stanceEc2stance aayMetrics prt,

|| 13.medium13.medium‘Neegress.\_-1—> Metrics..... ig)>80%B YW

\\\_ manage— .............\_BDAVAILABILITYZONE1A >) WebServerWebServer NATGateway Low.. 60%CPU:

| —— XL \ EBprivatesuener1| J

|.. co fe [Blpusticsuener1|

.. ome ---@

Ec2pete Ec2peice hmetrics\_\_/ —-allowtraffic,——\_| 13.mer 13.1goer NATGateway res

WebServer—WebServer

J (» TargetHealthGroup

(&) HTTP:80Checks

ni .. Application

Load

Route53 Internet Bal(Mult-AZ).

DNSService Gateway

xyzcorp.com

XN .

XL J
