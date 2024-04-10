FROM node:14-alpine

# add `/app/node_modules/.bin` to $PATH
ENV PATH /app/node_modules/.bin:$PATH

WORKDIR /app
RUN npm install -g serve

COPY . .

RUN npm install

#EXPOSE 3000

# start app
#CMD ["npm", "start"]

#RUN npm run build
RUN chmod +x /app/run
CMD ["/app/run"]
