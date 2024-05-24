# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS build

ENV DEBIAN_FRONTEND=noninteractive

#RUN apt-get update && \
#    apt-get install -y python3 python3-pip
    
#RUN apt install -y python3-sqlalchemy
# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

#get cloud sql proxy

 
#ADD connection name above


# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart compile exe bin/my_server.dart -o bin/my_server


# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/my_server /app/bin/
COPY --from=build /app/bin/main.py /app/bin/
COPY --from=build /app/bin/assets /app/bin/assets/
# Start server., "./cloud_sql_proxy -instances=$x-circle-416916:europe-west1:kappserver=tcp:0.0.0.0:3306"
EXPOSE 8080
ENTRYPOINT ["/app/bin/my_server"]