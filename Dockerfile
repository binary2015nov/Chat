FROM microsoft/dotnet:2.0-sdk
COPY src/Chat /app
WORKDIR /app
RUN ["dotnet", "restore", "--configfile", "NuGet.Config"]
RUN ["dotnet", "build"]
EXPOSE 5000/tcp
ENV ASPNETCORE_URLS http://*:5000
ENTRYPOINT ["dotnet", "run"]