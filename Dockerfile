FROM microsoft/dotnet:2.0-sdk
COPY src/Chat /app
COPY src/Chat/deploy /app
WORKDIR /app
RUN ["dotnet", "restore"]
RUN ["dotnet", "build"]
EXPOSE 5000/tcp
ENV ASPNETCORE_URLS https://*:5000
ENTRYPOINT ["dotnet", "run"]
