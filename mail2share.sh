#!/bin/bash

LOCKFILE=/tmp/mail2share.lock

if [ -f $LOCKFILE ] ; then
    echo ""
    echo "Lock file found, script is already running!"
    echo ""
    exit 1
fi

which getmail >/dev/null;
RETURNCODE=${PIPESTATUS[0]}
if [ "$RETURNCODE" -ne 0 ] ; then
    echo ""
    echo "Requirement 'getmail' not found. Please install!"
    echo " * Debian: apt get install getmail4"
    echo ""
    exit 1
fi

which ripmime >/dev/null;
RETURNCODE=${PIPESTATUS[0]}
if [ "$RETURNCODE" -ne 0 ] ; then
    echo ""
    echo "Requirement 'ripmime' not found. Please install!"
    echo " * Debian: apt get install ripmime"
    echo ""
    exit 1
fi

which curl >/dev/null;
RETURNCODE=${PIPESTATUS[0]}
if [ "$RETURNCODE" -ne 0 ] ; then
    echo ""
    echo "Requirement 'curl' not found. Please install!"
    echo " * Debian: apt get install curl"
    echo ""
    exit 1
fi

BASEPATH="$(dirname $0)"
MAILDIR="$BASEPATH/mails"
LOGFILE="$BASEPATH/log/fetchmails.log"
LOGFILE_ERROR="$BASEPATH/log/fetchmails_errors.log"
ATTACH_DIR="$BASEPATH/attachments"

if [ ! -f $BASEPATH/conf/fetchmails.conf ] ; then
    echo ""
    echo "Configuration $BASEPATH/conf/fetchmails.conf does not exist. Please copy $BASEPATH/conf/fetchmails.conf and create your own config"
    echo ""
    exit 1
fi

# Set parameters
source $BASEPATH/conf/fetchmails.conf

# Check parameters
if [ -z "$SMB_USER" ] ; then
    echo ""
    echo "Please define SMB_USER in $BASEPATH/conf/fetchmails.conf"
    echo ""
    exit 1
fi
if [ -z "$SMB_PASS" ] ; then
    echo ""
    echo "Please define SMB_PASS in $BASEPATH/conf/fetchmails.conf"
    echo ""
    exit 1
fi
if [ -z "$SMB_PATH" ] ; then
    echo ""
    echo "Please define SMB_PATH in $BASEPATH/conf/fetchmails.conf"
    echo ""
    exit 1
fi
if [ -z "$SMB_TYPE" ] ; then
    echo ""
    echo "Please define SMB_TYPE in $BASEPATH/conf/fetchmails.conf with 'curl' or 'mount' as transfer method!"
    echo ""
    exit 1
fi
if [ "$SMB_TYPE" != "curl" -a "$SMB_TYPE" != "mount" ] ; then
    echo ""
    echo "Please define SMB_TYPE in $BASEPATH/conf/fetchmails.conf with 'curl' or 'mount' as transfer method!"
    echo ""
    exit 1
fi
if [ -z "$POSTMASTER" ] ; then
    echo ""
    echo "Please define POSTMASTER in $BASEPATH/conf/fetchmails.conf"
    echo ""
    exit 1
fi

# Check requirements
if [ ! -d $MAILDIR ] ; then
    echo "> $MAILDIR does not exist, create."
    mkdir -p $MAILDIR/cur
    mkdir -p $MAILDIR/new
    mkdir -p $MAILDIR/tmp
fi
if [ ! -d $(dirname $LOGFILE) ] ; then
    echo "> $(dirname $LOGFILE) does not exist, create."
    mkdir -p $(dirname $LOGFILE)
fi
if [ ! -d $ATTACH_DIR ] ; then
    echo "> $ATTACH_DIR does not exist, create."
    mkdir -p $ATTACH_DIR
fi

if [ "$SMB_TYPE" == "mount" ] ; then
    mountpoint $ATTACH_DIR >/dev/null 2>&1
    RETURNCODE=${PIPESTATUS[0]}
    if [ "$RETURNCODE" -ne 0 ] ; then
        echo "[$(date)] Attachment directory $ATTACH_DIR is not mounted (code $RETURNCODE)" >> $LOGFILE_ERROR
        if [ ! -z "$POSTMASTER" ] ; then
            cat $LOGFILE_ERROR | mailx -s "[fetchmails] An error has occurred" $POSTMASTER
        fi
        cat $LOGFILE_ERROR
        rm $LOGFILE_ERROR
        exit 1
    else
        if [ -f $ATTACH_DIR/.test ] ; then rm $ATTACH_DIR/.test; fi
    fi

    touch -c $ATTACH_DIR/.test >/dev/null 2>&1
    RETURNCODE=${PIPESTATUS[0]}
    if [ "$RETURNCODE" -ne 0 ] ; then
        echo "[$(date)] Attachment directory $ATTACH_DIR is not writeable (code $RETURNCODE)" >> $LOGFILE_ERROR
        if [ ! -z "$POSTMASTER" ] ; then
            cat $LOGFILE_ERROR | mailx -s "[fetchmails] An error has occurred" $POSTMASTER
        fi
        cat $LOGFILE_ERROR
        rm $LOGFILE_ERROR
        exit 1
    else
        if [ -f $ATTACH_DIR/.test ] ; then rm $ATTACH_DIR/.test; fi
    fi
fi

# Create log file if it does not exist
touch $LOGFILE
echo "--------------------------------------------------------------------------------" >> $LOGFILE
date >> $LOGFILE

# Check mailbox configurations exist
ls -1 ./conf/*.getmail.conf >/dev/null 2>&1
RETURNCODE=${PIPESTATUS[0]}
if [ "$RETURNCODE" -ne 0 ] ; then
    echo ""
    echo "No mailbox configurations found. Please copy conf/user.getmail.conf.dist to conf/<yourname>.getmail.conf and set your mailbox configuration!"
    echo "For http://pyropus.ca/software/getmail/configuration.html for more informations about configuration."
    echo ""
    exit 1
fi

# fetch mail / execute different configs
find $BASEPATH/conf -type f -name "*.getmail.conf" -print0 | while IFS= read -r -d '' CONF; do
    getmail --getmaildir $BASEPATH/conf --rcfile $(basename $CONF) 2>&1 | tee $LOGFILE_ERROR >> $LOGFILE
    RETURNCODE=${PIPESTATUS[0]}
    if [ "$RETURNCODE" -ne 0 ] ; then
        echo "[$(date)] An error has occurred fetch mails from mailbox (code $RETURNCODE)" >> $LOGFILE_ERROR
        if [ ! -z "$POSTMASTER" ] ; then
            cat $LOGFILE_ERROR | mailx -s "[fetchmails] An error has occurred" $POSTMASTER
        fi
        cat $LOGFILE_ERROR
        rm $LOGFILE_ERROR
        exit 1
    else
        if [ -f $LOGFILE_ERROR ] ; then rm $LOGFILE_ERROR; fi
    fi
done

# Processing new mails
shopt -s nullglob
for MAIL in $MAILDIR/new/*
do
    echo "Processing : $MAIL" >> $LOGFILE
    ripmime -i $MAIL -v -d $ATTACH_DIR/ 2>&1 | tee $LOGFILE_ERROR >> $LOGFILE
    rm $ATTACH_DIR/textfile* 2>&1 | tee $LOGFILE_ERROR >> $LOGFILE
    RETURNCODE=${PIPESTATUS[0]}
    if [ "$RETURNCODE" -ne 0 ] ; then
        echo "[$(date)] An error has occurred get attachments from $MAIL (code $RETURNCODE)" >> $LOGFILE_ERROR
        if [ ! -z "$POSTMASTER" ] ; then
            cat $LOGFILE_ERROR | mailx -s "[fetchmails] An error has occurred" $POSTMASTER
        fi
        cat $LOGFILE_ERROR
        rm $LOGFILE_ERROR
        exit 1
    else
        if [ -f $LOGFILE_ERROR ] ; then rm $LOGFILE_ERROR; fi
    fi

    # delete mail
    echo "Deleting mail : $MAIL" >> $LOGFILE
    rm $MAIL >> $LOGFILE
done
shopt -u nullglob

# Processing new attachments with curl, when set
if [ "$SMB_TYPE" == "curl" ] ; then
    find $ATTACH_DIR -type f -name "*" -print0 | while IFS= read -r -d '' FILE; do
        echo "Transfer $FILE" >> $LOGFILE
        curl --upload-file "$FILE" -u $SMB_USER:$SMB_PASS smb://$SMB_PATH 2>&1 | tee $LOGFILE_ERROR >> $LOGFILE
        RETURNCODE=${PIPESTATUS[0]}
        if [ "$RETURNCODE" -ne 0 ] ; then
            echo "[$(date)] An error has occurred transfer attachment to "$FILE" target (code $RETURNCODE)" >> $LOGFILE_ERROR
            if [ ! -z "$POSTMASTER" ] ; then
                cat $LOGFILE_ERROR | mailx -s "[fetchmails] An error has occurred" $POSTMASTER
            fi
            cat $LOGFILE_ERROR
            rm $LOGFILE_ERROR
            exit 1
        else
            rm "$FILE"
            if [ -f $LOGFILE_ERROR ] ; then rm $LOGFILE_ERROR; fi
        fi
    done
fi
