import argparse
import json
import os

import sqlalchemy

CMD_SYS_VERSION = 0

def run(command):
    if command["cmd"] == CMD_SYS_VERSION:
        return {
            "sys.version": "yay it works",
        }
    if command["cmd"] == "connect":
        return testAPI()
    else:
        return {"error": "Unknown command."}


def testAPI():
    x= connect_unix_socket()
    return 3

def connect_unix_socket() -> sqlalchemy.engine.base.Engine:
    """Initializes a Unix socket connection pool for a Cloud SQL instance of MySQL."""
    # Note: Saving credentials in environment variables is convenient, but not
    # secure - consider a more secure solution such as
    # Cloud Secret Manager (https://cloud.google.com/secret-manager) to help
    # keep secrets safe.
    db_user = os.environ["DB_USER"]  # e.g. 'my-database-user'
    db_pass = os.environ["DB_PASS"]  # e.g. 'my-database-password'
    db_name = os.environ["DB_NAME"]  # e.g. 'my-database'
    unix_socket_path = os.environ[
        "INSTANCE_UNIX_SOCKET"
    ]  # e.g. '/cloudsql/project:region:instance'
    pool = sqlalchemy.create_engine(
        # Equivalent URL:
        # mysql+pymysql://<db_user>:<db_pass>@/<db_name>?unix_socket=<socket_path>/<cloud_sql_instance_name>
        sqlalchemy.engine.url.URL.create(
            drivername="mysql+pymysql",
            username=db_user,
            password=db_pass,
            database=db_name,
            query={"unix_socket": unix_socket_path},
        ),
    print("this is kinda working")
        # ...
    )
    return pool



if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--uuid")
    args = parser.parse_args()
    stream_start = f"`S`T`R`E`A`M`{args.uuid}`S`T`A`R`T`"
    stream_end = f"`S`T`R`E`A`M`{args.uuid}`E`N`D`"
    while True:
        cmd = input()
        cmd = json.loads(cmd)
        try:
            result = run(cmd)
        except Exception as e:
            result = {"exception": e.__str__()}
        result = json.dumps(result)
        print(stream_start + result + stream_end)