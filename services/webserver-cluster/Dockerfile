FROM ruby:2.3.1-alpine

COPY Gemfile /root/Gemfile

ENV UTIL_PACKAGES bash curl wget openssh-client jq unzip ca-certificates
ENV BUILD_PACKAGES curl-dev ruby-dev build-base
ENV RUBY_PACKAGES ruby ruby-io-console ruby-bundler
# Needed for AWS CLI
ENV PYTHON_PACKAGES python python-dev py-pip
ENV TF_PACKAGES git

RUN apk update && \
    apk upgrade && \
    apk add --update $UTIL_PACKAGES && \
    apk add --update $BUILD_PACKAGES && \
    apk add --update $RUBY_PACKAGES && \
    apk add --update $PYTHON_PACKAGES && \
    apk add --update $TF_PACKAGES && \
    pip install awscli

# Could add this to above to reduce size a tiny bit, but doesn't make much difference given overall size of image
#   apk --purge -v del py-pip && \
#    rm -rf /var/cache/apk/* && \
#    rm -rf /tmp/* && \


# RUN wget -q https://github.com/newcontext-oss/kitchen-terraform/blob/master/certs/gem-public_cert.pem && \
#     gem cert --add gem-public_cert.pem

# Need to use the bundle command for now to get some gems that we're pulling from source
RUN gem install json && \
    gem install yarjuf && \
    gem install aws-sdk && \
    gem install kitchen-ec2 && \
    cd /root && \
    bundle install

ENV TERRAFORM_VERSION=0.11.3
RUN wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin && \
    rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip

CMD ["/bin/bash"]