#!/bin/sh

###############################################################################
## システム名        :
## サーバ名          :
## スクリプト名      : cloudwatch_getmetrics.sh
##
## スクリプトコード  : bash
## 起動方法          : 1.crontabより起動
##                   :
##                   :
## 処理概要          : cloudwatchのメトリクスを取得する
##                   :
## 引数              : なし
##                   :
##                   :
## リターンコード    :  1 : 実行ユーザ異常
##                   :  2 : 二重起動状態
##                   : 11 : 異常終了(ERROR)
##                   :
##                   :
## 入出力ファイル    : IN . 個別変数ファイル
##                   : IN . 個別メッセージ定義ファイル
##                   : IN . 共通関数ファイル
##                   : IN . メッセージ定義ファイル
##                   : IN . インスタンスリストファイル
##                   : OUT. 実行ログ
##                   : OUT. cloudwatchメトリクスログ
## 注意点            :
##                   :
##------------------------------------------------------------------------
## リリース日       更新者         Version            修正内容
#
###############################################################################



###############################################################################
#
# 環境設定
#
###############################################################################
# 共通変数ファイル
if [ -f /opt/inf/common/common.env ] ; then
    . /opt/inf/common/common.env
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 共通変数ファイル読み込みエラー" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` CloudWatchメトリクス取得処理を異常終了します。" 2>&1
    exit 11
fi

# 個別変数ファイル
if [ -f ${COMMON_DIR}/cloudwatch.env ] ; then
    . ${COMMON_DIR}/cloudwatch.env
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 個別変数ファイル読み込みエラー" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` CloudWatchメトリクス取得処理を異常終了します。" 2>&1
    exit 11
fi

# 共通関数ファイル
if [ -f ${COMMON_DIR}/common.func ] ;then
    . ${COMMON_DIR}/common.func
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 共通関数ファイル読み込みエラー" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` CloudWatchメトリクス取得処理を異常終了します。" 2>&1
    exit 11
fi

# メッセージファイル
if [ -f ${COMMON_DIR}/message.env ] ; then
    . ${COMMON_DIR}/message.env /dev/null 2>&1
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 個別メッセージファイル読み込みエラー" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` CloudWatchメトリクス取得処理を異常終了します。" 2>&1

    exit 11
fi


# 個別関数ファイル
if [ -f ${COMMON_DIR}/cloudwatch.func ] ; then
    . ${COMMON_DIR}/cloudwatch.func  > /dev/null 2>&1
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 個別関数ファイル読み込みエラー" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` CloudWatchメトリクス取得処理を異常終了します。" 2>&1
    exit 11
fi


###############################################################################
# 実行チェック
###############################################################################
# スクリプト開始メッセージの表示
put_log "shell" "0000014" "I" "${I_0000014}"

# スクリプト実行チェックメッセージの表示
put_log "shell" "0000002" "I" "${I_0000002}"

# 実行ユーザーチェック
chk_user root
if [ $? -ne 0 ] ; then
    put_log "shell" "000B001" "E" "${E_000B001}"
    put_log "shell" "000B007" "E" "${E_000B007}"

    exit 1
fi

# ２重起動チェック
chk_proc ${SH_NAME} ${USER} 1
if [ $? -ne 0 ] ; then
    put_log "shell" "000B002" "E" "${E_000B002}"
    put_log "shell" "000B007" "E" "${E_000B007}"

    exit 2
fi


# スクリプト実行チェック完了メッセージの表示
put_log "shell" "0000003" "I" "${I_0000003}"

###############################################################################
# 主処理
###############################################################################
put_log "shell" "0000015" "I" "${I_0000015}"

###############################################################################
#-----------------------------------------------------------------------------#
# EBS
#-----------------------------------------------------------------------------#
###############################################################################
# EBSリストを取得
ebsInstanceGet

# EBSメトリクスをダウンロード
cat ${INFRA_DIR}/${EBSLIST}   | while read EBS
do
    InstanceId=`echo ${EBS}   | awk -F, '{print $1}'`
    InstanceName=`echo ${EBS} | awk -F, '{print $2}'`
    ebsDownloadMetrics ${InstanceId} ${InstanceName}
done

# EBSリスト削除
rm ${INFRA_DIR}/${EBSLIST}
rtcheck

###############################################################################
#-----------------------------------------------------------------------------#
## EC2
#-----------------------------------------------------------------------------#
###############################################################################

# EC2インスタンスリストを取得
ec2InstanceGet

# EC2メトリクスをダウンロード
cat ${INFRA_DIR}/${EC2LIST}   | while read EC2
do
    InstanceId=`echo ${EC2}   | awk -F, '{print $1}'`
    InstanceName=`echo ${EC2} | awk -F, '{print $2}'`
    ec2DownloadMetrics ${InstanceId} ${InstanceName}
done

# EC2インスタンスリストを削除
\rm ${INFRA_DIR}/${EC2LIST}
rtcheck

###############################################################################
#-----------------------------------------------------------------------------#
# ELB
#-----------------------------------------------------------------------------#
###############################################################################
# ELBインスタンスリスト取得
elbInstanceGet

# ELBメトリクスをダウンロード
cat ${INFRA_DIR}/${ELBLIST} | while read ELB
do
    InstanceId=`echo ${ELB} | awk -F, '{print $1}'`
    elbDownloadMetrics ${InstanceId}
done


# ELBインスタンスリスト削除
\rm ${INFRA_DIR}/${ELBLIST}

rtcheck


###############################################################################
#-----------------------------------------------------------------------------#
# イベント
#-----------------------------------------------------------------------------#
###############################################################################
# イベントリストを取得
eventsInstanceGet


# イベントメトリクスをダウンロード
cat ${INFRA_DIR}/${EVENTSLIST} | while read EVENTS
do
    InstanceId=`echo ${EVENTS} | awk -F, '{print $1}'`
    eventsDownloadMetrics ${InstanceId} ${InstanceName}
done


# イベントリスト削除
\rm ${INFRA_DIR}/${EVENTSLIST}
rtcheck


###############################################################################
#-----------------------------------------------------------------------------#
# Lambda
#-----------------------------------------------------------------------------#
###############################################################################
# Lambdaファンクションリスト取得

lambdaInstanceGet

# Lambdaメトリクスをダウンロード
cat ${INFRA_DIR}/${LAMBDALIST} | while read LAMBDA
do
  InstanceId=`echo ${LAMBDA}   | awk -F, '{print $1}'`
  lambdaDownloadMetrics ${InstanceId}
done

# Lambdaファンクションリスト削除
\rm ${INFRA_DIR}/${LAMBDALIST}
rtcheck


###############################################################################
#-----------------------------------------------------------------------------#
# ログ
#-----------------------------------------------------------------------------#
###############################################################################
# ロググループリスト取得
logsInstanceGet


# Logsメトリクスをダウンロード
cat ${INFRA_DIR}/${LOGSLIST} | while read LOGS
do
    InstanceId=`echo ${LOGS}   | awk -F, '{print $1}'`
    logsDownloadMetrics ${InstanceId}
done


# ロググループリストを削除
\rm ${INFRA_DIR}/${LOGSLIST}
rtcheck

###############################################################################
#-----------------------------------------------------------------------------#
# RDS
#-----------------------------------------------------------------------------#
###############################################################################
# RDSインスタンスリストを取得
rdsInstanceGet


# RDSメトリクスをダウンロード
cat ${INFRA_DIR}/${RDSLIST} | while read RDS
do
    InstanceId=`echo ${RDS} | awk -F, '{print $1}'`
    rdsDownloadMetrics ${InstanceId}
done

# RDSインスタンスリストを削除
\rm ${INFRA_DIR}/${RDSLIST}
rtcheck


put_log "shell" "0000017" "I" "${I_0000016}"
###############################################################################
# 終了処理
###############################################################################
if [[ ${ERR_FLG} -ne 0 ]] ; then
    put_log "shell" "0000008" "W" "${W_0000008}"
else
    put_log "shell" "0000018" "I" "${I_0000017}"
fi
