FROM microsoft/dotnet:latest
COPY src/Chat/bin/Debug/netcoreapp1.0/publish/ /root/
EXPOSE 5000/tcp
CMD ["dotnet","/root/Chat.dll"]