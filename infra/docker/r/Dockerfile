# =============================================================================
#  May R cho Cau 9: R 4.4 + RStudio Server + tidyverse (dplyr, tidyr, ggplot2)
#  + DBI/RSQLite. Mo RStudio tai http://localhost:8787
# =============================================================================
FROM rocker/tidyverse:4.4
LABEL org.opencontainers.image.source="https://github.com/ariushieu/ecommerce-bigdata-pipeline" \
      org.opencontainers.image.description="BTL De 01 - RStudio + tidyverse + RSQLite"

# --skipinstalled: goi nao anh goc da co thi bo qua
RUN install2.r --error --skipinstalled DBI RSQLite broom scales \
    && rm -rf /tmp/downloaded_packages

# Mo RStudio la vao thang thu muc bai lam (chi anh huong RStudio, khong anh huong Rscript)
RUN echo 'session-default-working-dir=/home/rstudio/src' >> /etc/rstudio/rsession.conf
