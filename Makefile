# =============================================================================
# BestPlayer 8K — Infraestrutura Nginx
# =============================================================================
# Uso:
#   make up               Sobe o nginx
#   make down             Para e remove o container
#   make restart          Reinicia o container
#   make reload           Recarrega a config sem reiniciar (zero downtime)
#   make logs             Logs em tempo real
#   make ps               Status do container
#   make test             Testa a configuração do nginx
#   make maintenance-on   Ativa modo de manutenção
#   make maintenance-off  Desativa modo de manutenção
# =============================================================================

COMPOSE = docker compose
CONTAINER = nginx-server

.PHONY: up down restart reload logs ps test maintenance-on maintenance-off

up:
	@echo "Subindo nginx..."
	$(COMPOSE) up -d
	@echo "nginx no ar."

down:
	@echo "Parando nginx..."
	$(COMPOSE) down

restart:
	$(COMPOSE) restart nginx

reload:
	@echo "Recarregando configuração nginx..."
	@$(COMPOSE) exec nginx nginx -t && \
		$(COMPOSE) exec nginx nginx -s reload && \
		echo "Configuração recarregada com sucesso." || \
		echo "Erro na configuração. Verifique acima."

logs:
	$(COMPOSE) logs -f --tail=100 nginx

ps:
	$(COMPOSE) ps

test:
	@echo "Testando configuração nginx..."
	$(COMPOSE) exec nginx nginx -t

maintenance-on:
	@echo "Ativando modo de manutenção..."
	@docker exec $(CONTAINER) touch /var/run/nginx-flags/.maintenance
	@docker exec $(CONTAINER) nginx -s reload
	@echo "Modo de manutenção ATIVADO — https://bestplayer8k.cloud"

maintenance-off:
	@echo "Desativando modo de manutenção..."
	@docker exec $(CONTAINER) rm -f /var/run/nginx-flags/.maintenance
	@docker exec $(CONTAINER) nginx -s reload
	@echo "Modo de manutenção DESATIVADO — sistema normal."
