#!/bin/sh
###############################################################################
## システム名        :
## サーバ名          :
##                   :
##                   :
##                   :
## スクリプト名      : logbackup.sh
## スクリプトコード  : bash
## 起動方法          : 1.crontabより起動
##                   :
##                   :
## 処理概要          : 各サーバのログをNASサーバのログ一次保管領域にコピーする
##                   :
## 引数              : なし
##                   :
##                   :
## リターンコード    :  1 : 実行ユーザ異常
##                   :  2 : 二重起動状態
##                   :  3 : アンマウント状態
##                   :  4 : 数値設定の異常
##                   : 11 : 異常終了(ERROR)
##                   :
##                   :
## 入出力ファイル    : IN . ログバックアップリストファイル
##                   : IN . 共通変数ファイル
##                   : IN . サーバ個別変数ファイル
##                   : IN . メッセージ定義ファイル
##                   : OUT. 共通エラーログ
## 注意点            :
##                   :
##------------------------------------------------------------------------
## リリース日       更新者         Version            修正内容
##
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
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 1次ログバックアップ処理を異常終了します。" 2>&1
    exit 11
fi

# 共通関数ファイル
if [ -f ${COMMON_DIR}/common.func ] ;then
    . ${COMMON_DIR}/common.func
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 共通関数ファイル読み込みエラー" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 1次ログバックアップ処理を異常終了します。" 2>&1
    exit 11
fi

# メッセージファイル
if [ -f ${COMMON_DIR}/message.env ] ; then
    . ${COMMON_DIR}/message.env /dev/null 2>&1
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` メッセージファイル読み込みエラー" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 1次ログバックアップ処理を異常終了します。" 2>&1
    exit 11
fi

# ログバックアップリスト
if [ -f ${INFRA_DIR}/${HOST_NAME}_backuplog.lst ] ; then
    . ${INFRA_DIR}/${HOST_NAME}_backuplog.lst  > /dev/null 2>&1
else
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` ログバックアップリストの読み込みエラー。" 2>&1
    logger -p local0.err " `date +%Y/%m/%d" "%H:%M:%S` 1次ログバックアップ処理を異常終了します。" 2>&1
    exit 11
fi

###############################################################################
#
# 実行チェック
#
###############################################################################

# スクリプト開始メッセージの表示
put_log "shell" "0000001" "I" "${I_0000001}"

# スクリプト実行チェックメッセージの表示
put_log "shell" "0000002" "I" "${I_0000002}"
# 実行ユーザーチェック
chk_user root
if [ $? -ne 0 ] ; then
    put_log "shell" "000B001" "E" "${E_000B001}"
    put_log "shell" "000B006" "E" "${E_000B006}"

    exit 1
fi

# ２重起動チェック
chk_proc ${SH_NAME} ${USER} 1
if [ $? -ne 0 ] ; then
    put_log "shell" "000B002" "E" "${E_000B002}"
    put_log "shell" "000B006" "E" "${E_000B006}"

    exit 2
fi

# マウントチェック
chk_mount ${LOGBKUP_MOUNTPOINT}
if [ $? -ne 0 ] ; then
    put_log "shell" "000B003" "E" "${E_000B003}"
    put_log "shell" "000B006" "E" "${E_000B006}"

    exit 3
fi

# バックアップ対象日付設定チェック
chk_numeric ${DAY}
if [ $? -ne 0 ] ; then
    put_log "shell" "000B004" "E" "${E_000B004} : DAY"
    put_log "shell" "000B006" "E" "${E_000B006}"

    exit 4
fi

# ローテート日付設定チェック
chk_numeric ${ROTATE}
if [ $? -ne 0 ] ; then
    put_log "shell" "000B004" "E" "${E_000B004} : ROTATE"
    put_log "shell" "000B006" "E" "${E_000B006}"

    exit 4
fi

# スクリプト実行チェック完了メッセージの表示
put_log "shell" "0000003" "I" "${I_0000003}"


###############################################################################
#
# 主処理
#
###############################################################################

put_log "shell" "0000004" "I" "${I_0000004}"

# バックアップ取得用ディレクトリ作成
### 開始メッセージ出力
put_log "shell" "0000005" "I" "${I_0000005}"

### 処理開始
mkdir ${LOGARC_DIR}/${LOGBKUP_WORK_DIR}
if [ $? -ne 0 ] ; then
    put_log "shell" "000B005" "E" "${E_000B005}"
    put_log "shell" "000B006" "E" "${E_000B006}"
    exit 11
else
    put_log "shell" "0000006" "I" "${I_0000006}"
fi

#============================================================================
# バックアップ処理
#============================================================================
## 開始メッセージ出力
put_log "shell" "0000007" "I" "${I_0000007}"

cat ${INFRA_DIR}/${HOST_NAME}_backuplog.lst | grep -v ^# | while read BKUPLOGCFG
do
    TARGETLOG=`echo ${BKUPLOGCFG} | awk -F "," '{ print $1 }'`
    BKUPLOG=`ls --full-time ${TARGETLOG}* | egrep ${TARGET_DATE} | awk '{print $9}'`
    LOGNAME=`ls -l ${BKUPLOG} | awk '{print $NF}' | sed -e 's/^\///g' -e 's/\//_/g'`
    SAVE_TYPE=`echo ${BKUPLOGCFG} | awk -F "," '{ print $2 }'`
    FILE_COUNT=`ls ${BKUPLOG} | wc -l`


   if [ -n "${BKUPLOG}" ] ; then
       case ${SAVE_TYPE} in
       cp)
            if [[ ${FILE_COUNT} -ne 1 ]] ; then
                cp -p ${BKUPLOG} ${LOGARC_DIR}/${LOGBKUP_WORK_DIR}/
                if [ $? -ne 0 ] ; then
                    put_log "shell" "000A001" "W" "${W_000A001} : ${LOGNAME}"
                      else
                          put_log "shell" "0000009" "I" "${I_0000009} : ${LOGNAME}"
                fi
            else
                cp -p ${BKUPLOG} ${LOGARC_DIR}/${LOGBKUP_WORK_DIR}/${LOGNAME}
                if [ $? -ne 0 ] ; then
                    put_log "shell" "000A001" "W" "${W_000A001} : ${LOGNAME}"
                      else
                          put_log "shell" "0000009" "I" "${I_0000009} : ${LOGNAME}"
                fi
            fi
        ;;
        mv)
            if [[ ${FILE_COUNT} -ne 1 ]] ; then
                mv ${BKUPLOG} ${LOGARC_DIR}/${LOGBKUP_WORK_DIR}/
                if [ $? -ne 0 ] ; then
                    put_log "shell" "000A001" "W" "${W_000A001} : ${LOGNAME}"
                      else
                          put_log "shell" "0000009" "I" "${I_0000009} : ${LOGNAME}"
                fi
            else
                mv ${BKUPLOG} ${LOGARC_DIR}/${LOGBKUP_WORK_DIR}/${LOGNAME}
                if [ $? -ne 0 ] ; then
                    put_log "shell" "000A001" "W" "${W_000A001} : ${LOGNAME}"
                      else
                          put_log "shell" "0000009" "I" "${I_0000009} : ${LOGNAME}"
                fi
            fi
        ;;
        *)
            put_log "shell" "000A002" "W" "${W_000A002} : ${LOGNAME}"
        ;;
        esac

    else
        put_log "shell" "000000A" "I" "${I_000000A} : ${TARGETLOG}"
    fi
done


## 終了メッセージ出力
put_log "shell" "0000008" "I" "${I_0000008}"

#============================================================================
# 圧縮処理
#============================================================================
## 開始メッセージ出力
put_log "shell" "000000B" "I" "${I_000000B}"

# 圧縮処理
cd ${LOGARC_DIR}
tar -cvJf ${COMPRESSION_NAME}.tar.xz ./${LOGBKUP_WORK_DIR}/*

if [ $? -ne 0 ] ; then
    ## WARNINGメッセージ出力
    put_log "shell" "000A003" "W" "${W_000A003}"
    SKIP_FLG=1
    WARN_FLG=1
else
    ## 終了メッセージ出力
    put_log "shell" "000000C" "I" "${I_000000C}"
fi

#============================================================================
# 削除処理
#============================================================================
## 開始メッセージ出力
if [[ ${SKIP_FLG} -ne 1 ]] ; then
    put_log "shell" "000000D" "I" "${I_000000D}"
else
    put_log "shell" "000A004" "W" "${W_000A004}"
    WARN_FLG=1
fi

## 削除処理
if [[ ${SKIP_FLG} -ne 1 ]] ; then
    rm -fr ${LOGBKUP_WORK_DIR}

    if [ $? -ne 0 ] ; then
        put_log "shell" "000A005" "W" "${I_000A005}"
        WARN_FLG=1
    else
        ## 終了メッセージ出力
        put_log "shell" "000000E" "I" "${I_000000E}"
    fi
fi


#============================================================================
# ローテーション処理
#============================================================================
## 開始メッセージ出力
put_log "shell" "000000F" "I" "${I_000000F} 保管世代数は${ROTATE}です。"

## ローテーション開始
if [[ ${ROTATE} -ne 0 ]] ; then
    ls -lat ${LOGARC_DIR}/*tar.xz | while read LOGROTATE
    do
        (( FILE_CNT=FILE_CNT+1 ))
        if [[ ${FILE_CNT} > ${ROTATE} ]]
        then
            # ログローテーションの実施
            rm `echo ${LOGROTATE} | awk '{print $9}'`
            if [ $? -ne 0 ] ; then
                # ローテーション失敗メッセージ
                put_log "shell" "000A006" "W" "${W_000A006}"
            fi
        fi
    done
else
    put_log "shell" "0000010" "I" "${I_0000010}"
fi

## ローテーション処理完了メッセージ
put_log "shell" "0000011" "I" "${I_0000011}"

## 主処理終了メッセージ出力
put_log "shell" "0000012" "I" "${I_0000012}"


###############################################################################
#
# 終了処理
#
###############################################################################
## 終了メッセージ出力
if [[ ${WARN_FLG} -ne 1 ]] ; then
    put_log "shell" "0000013" "I" "${I_0000013}"
else
    put_log "shell" "000A007" "W" "${W_000A007}"
fi
