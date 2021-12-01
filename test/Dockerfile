ARG SUT_IMAGE
FROM ${SUT_IMAGE}

RUN apk -U upgrade && \
    apk add git ncurses

RUN git clone https://github.com/bats-core/bats-core.git && \
    cd bats-core && \
    ./install.sh /usr/local

# bats add-ons
RUN git clone https://github.com/bats-core/bats-assert.git /opt/bats/addons/bats-assert && \
    git clone https://github.com/bats-core/bats-support.git /opt/bats/addons/bats-support && \
    git clone https://github.com/jasonkarns/bats-mock.git /opt/bats/addons/bats-mock

# location of the assets to test
ENV SUT_ASSETS_DIR=/opt/resource

# add our tests
ADD *.bats /opt/resource-tests/
ADD fixtures/* /opt/resource-tests/fixtures/

WORKDIR /opt/resource-tests
ENTRYPOINT ["bats"]
CMD ["."]
