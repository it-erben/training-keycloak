FROM quay.io/keycloak/keycloak:26.5.7
COPY owner-policies.jar /opt/keycloak/providers/owner-policies.jar
RUN /opt/keycloak/bin/kc.sh build --features=scripts --db=dev-file
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start-dev", "--features=scripts"]
